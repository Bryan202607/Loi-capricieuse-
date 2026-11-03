"""Génère tous les sons du jeu (WAV mono 22 kHz) dans assets/sfx.
Usage : python3 tools/gen_sounds.py   (nécessite numpy et scipy)
Tout est synthétisé par ce script : aucun droit d'auteur externe.
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(3)


def write(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def tone(f, dur, decay=6.0, harm=(1.0,), vol=1.0, attack=0.004):
    t = np.arange(int(SR * dur)) / SR
    s = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(harm))
    return s * np.exp(-decay * t) * np.minimum(1.0, t / attack) * vol


def place(buf, snd, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(snd), len(buf) - i)
    buf[i:i + n] += snd[:n]


def mix(length, items):
    buf = np.zeros(int(SR * length))
    for snd, at in items:
        place(buf, snd, at)
    return buf


def lowpass(x, f):
    b, a = butter(2, f / (SR / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, f):
    b, a = butter(2, f / (SR / 2), btype="high")
    return lfilter(b, a, x)


def chirp(f0, f1, dur, decay=5.0):
    t = np.arange(int(SR * dur)) / SR
    f = f0 + (f1 - f0) * (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-decay * t)


def fx():
    write("pickup", mix(0.3, [(tone(880, 0.12, 14, (1, 0.3)), 0.0), (tone(1320, 0.18, 12, (1, 0.3)), 0.07)]))
    write("gold", mix(0.7, [(tone(hz(f), 0.4, 7, (1, 0.35, 0.1)), i * 0.075)
                            for i, f in enumerate([84, 88, 91, 96, 100])]))
    write("deposit", mix(0.6, [(tone(988, 0.1, 12, (1, 0.4)), 0.0), (tone(1319, 0.4, 7, (1, 0.4, 0.15)), 0.08),
                               (tone(180, 0.15, 25, (1,), 0.6), 0.0)]))
    n = RNG.normal(size=int(SR * 0.7))
    t = np.arange(len(n)) / SR
    splash = lowpass(n, 2200) * np.exp(-6 * t) * np.minimum(1, t / 0.006)
    bloop = chirp(520, 140, 0.35, 7) * 0.56
    splash[:len(bloop)] += bloop
    write("splash", splash)
    write("bell", mix(1.2, [(tone(660, 1.2, 3.2, (1, 0.5, 0.25, 0.12), 1.0), 0.0)]), 0.55)
    tock = tone(190, 0.15, 30, (1, 0.5)) + lowpass(RNG.normal(size=int(SR * 0.15)), 900) * np.exp(-40 * np.arange(int(SR * 0.15)) / SR) * 0.6
    write("board", tock, 0.8)
    win = mix(1.6, [(tone(hz(f), 0.55 if i < 3 else 1.2, 4.5, (1, 0.4, 0.15)), i * 0.16)
                    for i, f in enumerate([72, 76, 79, 84])])
    write("win", win)
    lose = mix(1.4, [(tone(hz(67), 0.4, 5, (1, 0.5, 0.2)), 0.0), (tone(hz(63), 0.4, 5, (1, 0.5, 0.2)), 0.28),
                     (tone(hz(60), 0.8, 3.5, (1, 0.5, 0.2)), 0.56)])
    write("lose", lose)
    write("tick", tone(1000, 0.06, 40, (1, 0.3)), 0.5)
    write("tap", tone(520, 0.08, 30, (1, 0.3)), 0.5)



def swell(f, dur, vol=1.0, harm=(1.0,), peak=0.35):
    """Son qui monte puis retombe (suspense)."""
    t = np.arange(int(SR * dur)) / SR
    x = sum(a * np.sin(2 * np.pi * f * (k + 1) * t) for k, a in enumerate(harm))
    u = t / dur
    env = np.where(u < peak, u / peak, ((1 - u) / (1 - peak)) ** 1.6)
    return x * env * vol


def fx2():
    # Grondement sourd (la nature se dérègle)
    n = lowpass(RNG.normal(size=int(SR * 2.4)), 140)
    t = np.arange(len(n)) / SR
    env = np.minimum(1, t / 0.5) * np.exp(-1.2 * np.maximum(0, t - 0.5))
    write("rumble", (n / (np.max(np.abs(n)) + 1e-9) * 0.9 + 0.5 * np.sin(2 * np.pi * 52 * t)) * env, 0.85)
    # Accord tendu (suspense / révélation)
    sting = mix(2.4, [(swell(110.0, 2.4, 0.6, (1, 0.4)), 0.0), (swell(116.5, 2.4, 0.5, (1, 0.4)), 0.0),
                      (swell(164.8, 2.4, 0.4, (1, 0.3)), 0.2), (swell(1244.5, 1.8, 0.12, (1,)), 0.5)])
    write("sting", sting, 0.8)
    # Hibou : trois hou-hou
    hoots = np.zeros(int(SR * 2.0))
    for at, f0 in ((0.1, 430), (0.62, 410), (1.2, 380)):
        d = 0.38
        tt = np.arange(int(SR * d)) / SR
        f = f0 - 55 * (tt / d)
        ph = 2 * np.pi * np.cumsum(f) / SR
        env = np.sin(np.pi * tt / d) ** 1.4
        place(hoots, (np.sin(ph) + 0.35 * np.sin(2 * ph)) * env, at)
    write("owl", hoots, 0.55)
    # Grillons
    cr = np.zeros(int(SR * 3.2))
    for g in range(5):
        base = 0.1 + g * 0.6
        for k in range(5):
            at = base + k * 0.045
            tt = np.arange(int(SR * 0.03)) / SR
            place(cr, np.sin(2 * np.pi * (4300 + 120 * g) * tt) * np.sin(np.pi * tt / 0.03), at)
    write("crickets", cr, 0.35)
    # Aube : arpège clair + chants d'oiseaux
    dawn = mix(2.6, [(tone(hz(f), 0.9, 4, (1, 0.4, 0.15), 0.6), i * 0.22) for i, f in enumerate([72, 79, 84, 88])])
    for at in (0.9, 1.25, 1.55, 1.95):
        dawn = dawn + mix(2.6, [(chirp(2400, 3800, 0.14, 9) * 0.35, at)])
    write("dawn", dawn, 0.8)
    # Étoile : petit « ding » brillant
    write("star", tone(1568, 0.6, 5.5, (1, 0.5, 0.25, 0.1)), 0.8)


def music():
    bpm = 100
    beat = 60.0 / bpm
    bars = 8
    length = bars * 4 * beat
    buf = np.zeros(int(SR * (length + 3.0)))
    chords = [(48, [60, 64, 67]), (45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62])] * 2
    for b, (bass, tri) in enumerate(chords):
        t0 = b * 4 * beat
        dur = 4 * beat + 0.9
        t = np.arange(int(SR * dur)) / SR
        env = np.minimum(1.0, t / 0.5) * np.minimum(1.0, (dur - t) / 0.8)
        for n in tri:
            place(buf, 0.09 * np.sin(2 * np.pi * hz(n) * t) * env, t0)
        for k in (0, 2):
            place(buf, tone(hz(bass), 1.3, 2.6, (1, 0.4), 0.32), t0 + k * beat)
    scale = [72, 74, 76, 79, 81, 84]
    idx = 2
    for s in range(bars * 8):
        if RNG.random() < 0.58:
            idx = int(np.clip(idx + RNG.integers(-2, 3), 0, len(scale) - 1))
            place(buf, tone(hz(scale[idx]), 0.6, 5.5, (1, 0.3, 0.1), 0.22), s * beat / 2)
    for s in range(bars * 4 * 2):
        h = highpass(RNG.normal(size=int(SR * 0.05)), 5000) * np.exp(-60 * np.arange(int(SR * 0.05)) / SR)
        place(buf, h * (0.05 if s % 2 else 0.08), s * beat / 2)
    n = int(SR * length)
    tail = buf[n:]
    buf = buf[:n]
    buf[:len(tail)] += tail[:len(buf)]
    write("music", buf, 0.45)


if __name__ == "__main__":
    fx()
    fx2()
    music()
    print("Sons générés dans", os.path.abspath(OUT))

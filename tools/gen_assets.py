"""Génère tous les graphismes du jeu (PNG) dans ../assets.
Usage : python3 tools/gen_assets.py   (nécessite Pillow, numpy, scipy)
Tous les visuels sont créés par ce script : aucun droit d'auteur externe.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets")
os.makedirs(OUT, exist_ok=True)
SS = 4  # suréchantillonnage pour des bords propres
random.seed(7)


def save(img, name):
    img.save(os.path.join(OUT, name))


def pnoise(h, w, sigma, seed):
    """Bruit continu qui se répète sans couture."""
    r = np.random.default_rng(seed)
    n = gaussian_filter(r.random((h, w)), sigma, mode="wrap")
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def union(*masks):
    m = masks[0]
    for o in masks[1:]:
        m = ImageChops.lighter(m, o)
    return m


def inter(a, b):
    return ImageChops.multiply(a, b)


class C:
    """Petit canevas dessiné à 4x puis réduit."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

    def m(self, kind, a, r=0):
        mk = Image.new("L", self.im.size, 0)
        d = ImageDraw.Draw(mk)
        if kind == "ell":
            d.ellipse([v * SS for v in a], fill=255)
        elif kind == "poly":
            d.polygon([(x * SS, y * SS) for x, y in a], fill=255)
        elif kind == "rr":
            d.rounded_rectangle([v * SS for v in a], radius=r * SS, fill=255)
        elif kind == "rect":
            d.rectangle([v * SS for v in a], fill=255)
        return mk

    def fill(self, mask, c1, c2=None, hl=None, rad=None, alpha=1.0, grain=0.0):
        w, h = self.im.size
        bb = mask.getbbox()
        if bb is None:
            return
        if c2 is None:
            col = np.zeros((h, w, 3), np.float32) + np.array(c1, np.float32)
        else:
            if hl is None:
                hx, hy = bb[0] + (bb[2] - bb[0]) * 0.35, bb[1] + (bb[3] - bb[1]) * 0.3
            else:
                hx, hy = hl[0] * SS, hl[1] * SS
            if rad is None:
                rad = math.hypot(bb[2] - bb[0], bb[3] - bb[1]) * 0.6
            else:
                rad *= SS
            yy, xx = np.mgrid[0:h, 0:w]
            t = np.clip(np.sqrt((xx - hx) ** 2 + (yy - hy) ** 2) / rad, 0, 1)[..., None]
            col = np.array(c1, np.float32) * (1 - t) + np.array(c2, np.float32) * t
        if grain:
            g = np.random.default_rng(5).normal(0, grain, (h, w, 1))
            col = col + g
        a = (np.array(mask, np.float32) * alpha)
        layer = np.dstack([np.clip(col, 0, 255), a]).astype(np.uint8)
        self.im = Image.alpha_composite(self.im, Image.fromarray(layer, "RGBA"))

    def shadow(self, kind, a, blur=3, alpha=100, r=0):
        mk = self.m(kind, a, r).filter(ImageFilter.GaussianBlur(blur * SS))
        self.fill(mk, (0, 0, 0), alpha=alpha / 255.0)

    def lines(self, mask, segs, color, width, alpha=1.0):
        layer = Image.new("L", self.im.size, 0)
        d = ImageDraw.Draw(layer)
        for (x1, y1), (x2, y2) in segs:
            d.line([(x1 * SS, y1 * SS), (x2 * SS, y2 * SS)], fill=255, width=max(1, int(width * SS)))
        self.fill(inter(layer, mask), color, alpha=alpha)

    def polyline(self, pts, color, width, alpha=1.0):
        layer = Image.new("L", self.im.size, 0)
        d = ImageDraw.Draw(layer)
        d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=max(1, int(width * SS)), joint="curve")
        self.fill(layer, color, alpha=alpha)

    def out(self):
        return self.im.resize((self.w, self.h), Image.LANCZOS)


# ---------------------------------------------------------------- terrain
def make_grass(size=256):
    n1, n2, n3 = pnoise(size, size, 26, 1), pnoise(size, size, 7, 2), pnoise(size, size, 1.6, 3)
    t = 0.55 * n1 + 0.3 * n2 + 0.15 * n3
    t = (t - t.min()) / (t.max() - t.min())
    dark, light = np.array([70, 132, 50]), np.array([132, 190, 80])
    arr = dark * (1 - t[..., None]) + light * t[..., None]
    img = Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")
    over = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(2600):
        x, y = random.uniform(0, size), random.uniform(0, size)
        ln = random.uniform(4, 10)
        ang = random.uniform(-0.55, 0.55) - math.pi / 2
        dx, dy = math.cos(ang) * ln, math.sin(ang) * ln
        col = random.choice([(52, 110, 36, 150), (160, 212, 96, 120), (98, 158, 58, 140)])
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d.line([(x + ox, y + oy), (x + ox + dx, y + oy + dy)], fill=col, width=1)
    return Image.alpha_composite(img, over)


def make_water(w=256, h=240, ice=False):
    yy = np.linspace(0, 1, h)[:, None]
    depth = (1 - np.abs(yy - 0.5) * 2) ** 0.8
    if ice:
        c_sh, c_dp = np.array([226, 244, 252]), np.array([150, 205, 232])
    else:
        c_sh, c_dp = np.array([104, 196, 218]), np.array([20, 80, 150])
    base = c_sh * (1 - depth[..., None]) + c_dp * depth[..., None]
    base = np.broadcast_to(base, (h, w, 3)).copy()
    v = 0.6 * pnoise(h, w, (3, 14), 11) + 0.4 * pnoise(h, w, (2, 8), 12)
    v = (v - v.min()) / (v.max() - v.min())
    base *= 0.9 + 0.2 * v[..., None]
    hl = np.clip((pnoise(h, w, (1.5, 10), 13) - 0.62) * 6, 0, 1)
    base = base * (1 - hl[..., None] * 0.5) + 255 * hl[..., None] * 0.5
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    if ice:
        over = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(over)
        for _ in range(26):
            x, y = random.uniform(0, w), random.uniform(0, h)
            pts = [(x, y)]
            for _ in range(random.randint(3, 6)):
                x += random.uniform(-26, 26)
                y += random.uniform(-14, 14)
                pts.append((x, y))
            for ox in (-w, 0, w):
                d.line([(px + ox, py) for px, py in pts], fill=(255, 255, 255, 190), width=2)
        img = Image.alpha_composite(img, over)
    return img


def make_bank(w=256, h=48, south=False):
    S = 4
    W, H = w * S, h * S
    xs = np.arange(W)
    wave = 24 * S + 3 * S * np.sin(2 * math.pi * xs / W * 2) + 1.5 * S * np.sin(2 * math.pi * xs / W * 5 + 1)
    ys = np.arange(H)[:, None]
    dist = np.clip((wave[None, :] - ys) / (22 * S), 0, 1)
    sand_l, sand_d = np.array([232, 214, 160]), np.array([176, 150, 96])
    wet = np.array([150, 124, 80])
    col = sand_l * dist[..., None] + wet * (1 - dist[..., None])
    col = col * (0.95 + 0.1 * np.random.default_rng(3).random((H, W, 1)))
    alpha = np.where(ys < wave[None, :], np.clip(ys / (10.0 * S), 0, 1), 0.0)
    foam_a = np.where((ys >= wave[None, :]) & (ys < wave[None, :] + 6 * S),
                      0.75 * (1 - (ys - wave[None, :]) / (6 * S)), 0.0)
    colf = col * (1 - foam_a[..., None]) + 255 * foam_a[..., None]
    a = np.clip(np.maximum(alpha, foam_a), 0, 1)
    arr = np.dstack([np.clip(colf, 0, 255), a * 255]).astype(np.uint8)
    img = Image.fromarray(arr, "RGBA").resize((w, h), Image.LANCZOS)
    return img.transpose(Image.FLIP_TOP_BOTTOM) if south else img


def make_landing():
    c = C(150, 60)
    c.shadow("rr", (8, 8, 142, 56), 3, 90, r=4)
    plank = c.m("rr", (6, 4, 144, 54), 4)
    c.fill(plank, (196, 146, 90), (130, 88, 48), hl=(60, 20), rad=120, grain=6)
    seg = []
    for i in range(1, 8):
        x = 6 + i * (138 / 8)
        seg.append(((x, 4), (x, 54)))
    c.lines(plank, seg, (70, 44, 22), 1.4, alpha=0.8)
    nails = []
    for i in range(8):
        x = 6 + (i + 0.5) * (138 / 8)
        for y in (12, 46):
            nails.append(c.m("ell", (x - 1.4, y - 1.4, x + 1.4, y + 1.4)))
    c.fill(union(*nails), (60, 40, 24), alpha=0.9)
    return c.out()


# ---------------------------------------------------------------- sprites
def make_player():
    c = C(96, 112)
    c.shadow("ell", (20, 84, 76, 102), 3, 110)
    for x0 in (28, 50):
        c.fill(c.m("ell", (x0, 80, x0 + 18, 95)), (96, 64, 42), (46, 28, 18))
    body = c.m("rr", (28, 48, 68, 88), 12)
    c.fill(body, (84, 204, 182), (22, 114, 106), hl=(40, 56), rad=52)
    c.fill(inter(body, c.m("rect", (28, 70, 68, 77))), (128, 82, 42), (84, 52, 26), hl=(48, 72), rad=40)
    for x0 in (17, 61):
        c.fill(c.m("ell", (x0, 54, x0 + 18, 80)), (252, 218, 180), (212, 160, 120))
    head = c.m("ell", (26, 14, 70, 60))
    c.fill(head, (255, 228, 196), (220, 168, 128), hl=(42, 30), rad=44)
    cap = inter(c.m("ell", (23, 6, 73, 52)), c.m("rect", (0, 0, 96, 31)))
    c.fill(cap, (240, 90, 80), (170, 34, 40), hl=(40, 14), rad=40)
    c.fill(c.m("rr", (21, 26, 75, 34), 4), (210, 62, 62), (140, 26, 34), hl=(40, 28), rad=40)
    c.fill(c.m("ell", (43, 2, 53, 12)), (255, 255, 255), (214, 214, 224))
    for x0 in (37, 52):
        c.fill(c.m("ell", (x0, 38, x0 + 7, 48)), (36, 28, 30))
        c.fill(c.m("ell", (x0 + 1.5, 39.5, x0 + 4, 42.5)), (255, 255, 255))
    for x0 in (30, 59):
        c.fill(c.m("ell", (x0, 46, x0 + 8, 52)), (255, 140, 140), alpha=0.5)
    c.polyline([(42 + i * 1.4, 51 + 3.2 * math.sin(math.pi * i / 8)) for i in range(9)], (120, 54, 50), 1.4)
    return c.out()


def make_fruit():
    c = C(56, 64)
    c.shadow("ell", (10, 50, 46, 62), 2.5, 100)
    body = union(c.m("ell", (6, 14, 32, 52)), c.m("ell", (24, 14, 50, 52)))
    c.fill(body, (255, 128, 104), (170, 22, 30), hl=(20, 26), rad=36)
    c.fill(c.m("ell", (22, 12, 34, 20)), (110, 16, 22), alpha=0.5)
    c.fill(c.m("ell", (12, 20, 23, 31)), (255, 255, 255), alpha=0.55)
    c.fill(c.m("poly", [(27, 6), (31, 6), (32, 18), (26, 18)]), (116, 76, 38), (74, 46, 22))
    c.fill(c.m("poly", [(31, 12), (44, 3), (49, 11), (38, 18)]), (130, 214, 90), (46, 130, 48))
    return c.out()


def boat_poly(cx, scale_x=1.0, scale_y=1.0, cy=68):
    right = [(46, 4), (60, 20), (70, 44), (74, 76), (70, 106), (60, 122), (46, 126)]
    left = [(92 - x, y) for x, y in reversed(right[1:-1])]
    pts = right + left
    return [(cx + (x - cx) * scale_x, cy + (y - cy) * scale_y) for x, y in pts]


def make_boat():
    c = C(92, 132)
    c.shadow("poly", [(x + 5, y + 7) for x, y in boat_poly(46)], 4, 120)
    c.fill(c.m("poly", boat_poly(46)), (150, 96, 50), (84, 50, 24), hl=(34, 40), rad=90)
    inner = c.m("poly", boat_poly(46, 0.74, 0.9))
    c.fill(inner, (200, 150, 96), (140, 96, 54), hl=(40, 50), rad=80, grain=5)
    segs = [((0, y), (92, y)) for y in range(22, 116, 9)]
    c.lines(inner, segs, (92, 58, 28), 1.2, alpha=0.55)
    c.fill(inter(inner, c.m("rect", (0, 56, 92, 64))), (120, 78, 40), (84, 52, 26))
    c.fill(inter(inner, c.m("rect", (0, 92, 92, 100))), (120, 78, 40), (84, 52, 26))
    for y in (60, 96):
        for x in (31, 61):
            c.fill(c.m("ell", (x - 1.3, y - 1.3, x + 1.3, y + 1.3)), (50, 32, 18), alpha=0.9)
    c.polyline([(14, 70), (2, 80)], (110, 74, 36), 2.2)
    c.polyline([(78, 70), (90, 80)], (110, 74, 36), 2.2)
    c.fill(c.m("ell", (-1, 77, 7, 86)), (130, 90, 44))
    c.fill(c.m("ell", (85, 77, 93, 86)), (130, 90, 44))
    c.polyline([(46, 10), (46, 22)], (230, 220, 190), 1.6, alpha=0.7)
    return c.out()


def make_hut():
    c = C(220, 200)
    c.shadow("ell", (14, 170, 206, 196), 4, 120)
    wall = c.m("rect", (40, 92, 180, 180))
    c.fill(wall, (214, 164, 104), (150, 102, 56), hl=(80, 110), rad=140, grain=5)
    c.lines(wall, [((x, 92), (x, 180)) for x in range(52, 180, 14)], (96, 60, 30), 1.2, alpha=0.55)
    c.fill(c.m("rect", (40, 168, 180, 182)), (150, 150, 150), (96, 96, 100))
    door = union(c.m("rect", (98, 128, 124, 182)), c.m("ell", (98, 112, 124, 144)))
    c.fill(door, (118, 78, 40), (64, 38, 20), hl=(110, 140), rad=50)
    c.fill(c.m("ell", (116, 150, 121, 155)), (240, 210, 110))
    c.fill(c.m("rr", (136, 110, 168, 142), 3), (86, 54, 28))
    c.fill(c.m("rr", (139, 113, 165, 139), 2), (190, 232, 250), (96, 168, 214), hl=(146, 118), rad=36)
    c.lines(c.m("rect", (139, 113, 165, 139)), [((152, 113), (152, 139)), ((139, 126), (165, 126))], (86, 54, 28), 1.6)
    c.fill(c.m("rect", (150, 32, 172, 70)), (172, 170, 166), (110, 108, 106), hl=(158, 40), rad=40)
    c.fill(c.m("rect", (147, 28, 175, 36)), (120, 118, 116), (80, 78, 78))
    left = c.m("poly", [(10, 98), (110, 20), (110, 98)])
    right = c.m("poly", [(110, 20), (210, 98), (110, 98)])
    c.fill(left, (236, 96, 84), (176, 44, 44), hl=(60, 60), rad=110)
    c.fill(right, (176, 52, 52), (114, 28, 36), hl=(150, 60), rad=110)
    for y in range(34, 98, 10):
        c.lines(union(left, right), [((0, y), (220, y))], (80, 20, 24), 1.1, alpha=0.35)
    c.fill(c.m("rect", (8, 96, 212, 104)), (120, 34, 40), (78, 20, 26))
    c.fill(c.m("rect", (8, 96, 212, 98)), (255, 160, 140), alpha=0.4)
    return c.out()


def make_tree():
    c = C(128, 160)
    c.shadow("ell", (20, 134, 112, 156), 4, 110)
    c.fill(c.m("poly", [(54, 96), (74, 96), (78, 148), (50, 148)]), (140, 94, 52), (82, 52, 26), hl=(60, 110), rad=50)
    blobs = [(64, 52, 42), (36, 78, 32), (92, 78, 32), (64, 88, 36)]
    for cx, cy, r in blobs:
        c.fill(c.m("ell", (cx - r, cy - r, cx + r, cy + r)), (64, 140, 64), (26, 84, 44), hl=(cx - r * 0.3, cy - r * 0.4), rad=r * 1.6)
    for cx, cy, r in [(60, 40, 22), (34, 70, 16), (88, 66, 18), (62, 74, 20)]:
        c.fill(c.m("ell", (cx - r, cy - r, cx + r, cy + r)), (140, 206, 98), (72, 160, 72), hl=(cx - r * 0.4, cy - r * 0.5), rad=r * 1.5, alpha=0.8)
    return c.out()


def make_bush():
    c = C(72, 56)
    c.shadow("ell", (6, 40, 66, 54), 3, 100)
    for cx, cy, r in [(36, 28, 20), (20, 34, 15), (52, 34, 15)]:
        c.fill(c.m("ell", (cx - r, cy - r, cx + r, cy + r)), (86, 164, 76), (34, 100, 50), hl=(cx - r * 0.3, cy - r * 0.5), rad=r * 1.7)
    for x, y in [(26, 24), (44, 20), (36, 34), (54, 32), (16, 34)]:
        c.fill(c.m("ell", (x - 2.5, y - 2.5, x + 2.5, y + 2.5)), (240, 90, 120))
    return c.out()


def make_rock():
    c = C(64, 48)
    c.shadow("ell", (6, 34, 58, 46), 3, 100)
    pts = [(8, 36), (14, 18), (28, 8), (46, 12), (56, 28), (54, 38), (30, 42)]
    c.fill(c.m("poly", pts), (190, 190, 192), (92, 92, 100), hl=(26, 14), rad=46)
    c.fill(c.m("poly", [(14, 18), (28, 8), (36, 14), (22, 24)]), (240, 240, 244), alpha=0.5)
    return c.out()


def make_flower(name, petal, center=(255, 214, 80)):
    c = C(28, 28)
    c.shadow("ell", (6, 20, 22, 27), 1.5, 80)
    c.polyline([(14, 26), (14, 14)], (70, 140, 60), 1.8)
    for i in range(5):
        a = i * 2 * math.pi / 5
        x, y = 14 + math.cos(a) * 5.5, 12 + math.sin(a) * 5.5
        c.fill(c.m("ell", (x - 3.6, y - 3.6, x + 3.6, y + 3.6)), petal)
    c.fill(c.m("ell", (11, 9, 17, 15)), center)
    save(c.out(), name)


def main():
    save(make_grass(), "grass.png")
    save(make_water(), "water.png")
    save(make_water(ice=True), "ice.png")
    save(make_bank(), "bank_n.png")
    save(make_bank(south=True), "bank_s.png")
    save(make_landing(), "landing.png")
    save(make_player(), "player.png")
    save(make_fruit(), "fruit.png")
    save(make_boat(), "boat.png")
    save(make_hut(), "hut.png")
    save(make_tree(), "tree.png")
    save(make_bush(), "bush.png")
    save(make_rock(), "rock.png")
    make_flower("flower_a.png", (255, 255, 255))
    make_flower("flower_b.png", (255, 150, 190))
    make_flower("flower_c.png", (150, 170, 255))
    print("Graphismes générés dans", os.path.abspath(OUT))


if __name__ == "__main__":
    main()

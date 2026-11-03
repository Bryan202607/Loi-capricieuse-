"""Graphismes de la version 3 : personnage animé, villageois, 2e maison,
fruit doré, étoiles de score et lueurs (nuit).
Usage : python3 tools/gen_assets.py && python3 tools/gen_assets2.py
"""
import math
import os

import numpy as np
from PIL import Image

from gen_assets import C, OUT, inter, make_hut, save, union


def make_person(skin=((255, 228, 196), (220, 168, 128)),
                shirt=((84, 204, 182), (22, 114, 106)),
                hat=((240, 90, 80), (170, 34, 40)),
                band=((210, 62, 62), (140, 26, 34)),
                style="cap", step=0, cheer=False):
    c = C(96, 112)
    dy = -2 if step else 0
    c.shadow("ell", (20, 84, 76, 102), 3, 110)

    # pieds
    lf_y = 80 + {0: 0, 1: -5, 2: 2}[step]
    rf_y = 80 + {0: 0, 1: 2, 2: -5}[step]
    lf_x, rf_x = (28, 50)
    if cheer:
        lf_x, rf_x = (24, 54)
        lf_y = rf_y = 80
    for x0, y0 in ((lf_x, lf_y), (rf_x, rf_y)):
        c.fill(c.m("ell", (x0, y0, x0 + 18, y0 + 15)), (96, 64, 42), (46, 28, 18))

    # corps
    body = c.m("rr", (28, 48 + dy, 68, 88 + dy), 12)
    c.fill(body, shirt[0], shirt[1], hl=(40, 56 + dy), rad=52)
    c.fill(inter(body, c.m("rect", (28, 70 + dy, 68, 77 + dy))), (128, 82, 42), (84, 52, 26), hl=(48, 72), rad=40)

    # bras
    if cheer:
        arms = [(8, 28, 26, 58), (70, 28, 88, 58)]
    else:
        l_off = {0: 0, 1: -5, 2: 4}[step]
        r_off = {0: 0, 1: 4, 2: -5}[step]
        arms = [(17, 54 + dy + l_off, 35, 80 + dy + l_off), (61, 54 + dy + r_off, 79, 80 + dy + r_off)]
    for a in arms:
        c.fill(c.m("ell", a), skin[0], skin[1])

    # tête
    head = c.m("ell", (26, 14 + dy, 70, 60 + dy))
    c.fill(head, skin[0], skin[1], hl=(42, 30 + dy), rad=44)

    # chapeau
    if style == "cap":
        cap = inter(c.m("ell", (23, 6 + dy, 73, 52 + dy)), c.m("rect", (0, 0, 96, 31 + dy)))
        c.fill(cap, hat[0], hat[1], hl=(40, 14 + dy), rad=40)
        c.fill(c.m("rr", (21, 26 + dy, 75, 34 + dy), 4), band[0], band[1], hl=(40, 28 + dy), rad=40)
        c.fill(c.m("ell", (43, 2 + dy, 53, 12 + dy)), (255, 255, 255), (214, 214, 224))
    else:  # chapeau de paille
        c.fill(c.m("ell", (12, 22 + dy, 84, 40 + dy)), hat[0], hat[1], hl=(40, 28 + dy), rad=50)
        dome = inter(c.m("ell", (27, 4 + dy, 69, 36 + dy)), c.m("rect", (0, 0, 96, 31 + dy)))
        c.fill(dome, hat[0], hat[1], hl=(40, 10 + dy), rad=36)
        c.fill(inter(c.m("rect", (26, 22 + dy, 70, 29 + dy)), c.m("ell", (27, 4 + dy, 69, 36 + dy))), band[0], band[1])

    # visage
    for x0 in (37, 52):
        c.fill(c.m("ell", (x0, 38 + dy, x0 + 7, 48 + dy)), (36, 28, 30))
        c.fill(c.m("ell", (x0 + 1.5, 39.5 + dy, x0 + 4, 42.5 + dy)), (255, 255, 255))
    for x0 in (30, 59):
        c.fill(c.m("ell", (x0, 46 + dy, x0 + 8, 52 + dy)), (255, 140, 140), alpha=0.45)
    if cheer:
        c.fill(c.m("ell", (40, 50 + dy, 56, 61 + dy)), (110, 30, 40))
        c.fill(c.m("ell", (43, 56 + dy, 53, 61 + dy)), (240, 120, 120))
    else:
        c.polyline([(42 + i * 1.4, 51 + dy + 3.2 * math.sin(math.pi * i / 8)) for i in range(9)], (120, 54, 50), 1.4)
    return c.out()


VILLAGERS = [
    dict(skin=((250, 214, 176), (212, 160, 120)), shirt=((255, 170, 90), (214, 100, 40)),
         hat=((90, 150, 240), (36, 80, 180)), band=((250, 250, 250), (200, 200, 210)), style="cap"),
    dict(skin=((196, 140, 100), (150, 100, 66)), shirt=((190, 130, 230), (110, 60, 160)),
         hat=((240, 214, 120), (190, 150, 60)), band=((220, 70, 70), (150, 30, 40)), style="straw"),
    dict(skin=((226, 180, 140), (186, 134, 96)), shirt=((130, 210, 110), (50, 140, 60)),
         hat=((250, 210, 70), (200, 150, 20)), band=((60, 60, 70), (30, 30, 40)), style="cap"),
    dict(skin=((140, 94, 64), (96, 60, 38)), shirt=((255, 140, 170), (200, 70, 110)),
         hat=((240, 214, 120), (190, 150, 60)), band=((70, 130, 220), (30, 80, 170)), style="straw"),
]


def make_hut2():
    im = make_hut().convert("RGBA")
    arr = np.array(im)
    hsv = Image.fromarray(arr[..., :3]).convert("HSV")
    h, s, v = [np.array(x) for x in hsv.split()]
    mask = ((h < 14) | (h > 240)) & (s > 110)
    h = np.where(mask, 150, h).astype(np.uint8)
    rgb = Image.merge("HSV", (Image.fromarray(h), Image.fromarray(s), Image.fromarray(v))).convert("RGB")
    out = np.dstack([np.array(rgb), arr[..., 3]])
    img = Image.fromarray(out, "RGBA")
    return img.resize((int(img.width * 0.72), int(img.height * 0.72)), Image.LANCZOS)


def make_gold_fruit():
    c = C(56, 64)
    c.shadow("ell", (10, 50, 46, 62), 2.5, 100)
    body = union(c.m("ell", (6, 14, 32, 52)), c.m("ell", (24, 14, 50, 52)))
    c.fill(body, (255, 244, 160), (214, 140, 10), hl=(20, 26), rad=36)
    c.fill(c.m("ell", (22, 12, 34, 20)), (150, 90, 0), alpha=0.5)
    c.fill(c.m("ell", (12, 20, 23, 31)), (255, 255, 255), alpha=0.7)
    c.fill(c.m("poly", [(27, 6), (31, 6), (32, 18), (26, 18)]), (116, 76, 38), (74, 46, 22))
    c.fill(c.m("poly", [(31, 12), (44, 3), (49, 11), (38, 18)]), (150, 220, 100), (60, 150, 60))
    return c.out()


def star_poly(cx, cy, r_out, r_in):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def make_star(on=True):
    c = C(72, 72)
    c.shadow("poly", [(x + 1, y + 3) for x, y in star_poly(36, 38, 32, 14)], 2, 120)
    m = c.m("poly", star_poly(36, 36, 32, 14))
    if on:
        c.fill(m, (255, 240, 130), (240, 150, 20), hl=(30, 26), rad=44)
        c.fill(c.m("poly", star_poly(36, 36, 22, 9)), (255, 255, 220), alpha=0.35)
    else:
        c.fill(m, (150, 156, 164), (92, 98, 108), hl=(30, 26), rad=44)
    return c.out()


def make_glow(size=256):
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.sqrt((xx - size / 2 + 0.5) ** 2 + (yy - size / 2 + 0.5) ** 2) / (size / 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    arr = np.dstack([np.full((size, size), 255), np.full((size, size), 255), np.full((size, size), 255), a * 255])
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def main():
    save(make_person(step=0), "player.png")
    save(make_person(step=1), "player_w1.png")
    save(make_person(step=2), "player_w2.png")
    save(make_person(cheer=True), "player_cheer.png")
    for i, v in enumerate(VILLAGERS):
        save(make_person(step=0, **v), "vil%d_idle.png" % i)
        save(make_person(cheer=True, **v), "vil%d_cheer.png" % i)
    save(make_hut2(), "hut2.png")
    save(make_gold_fruit(), "gold.png")
    save(make_star(True), "star.png")
    save(make_star(False), "star_off.png")
    save(make_glow(), "glow.png")
    print("Graphismes v3 générés dans", os.path.abspath(OUT))


if __name__ == "__main__":
    main()

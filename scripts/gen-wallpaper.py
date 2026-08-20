#!/usr/bin/env python3
"""Generate the Nothing wallpaper: concrete grey, grain, geometric shapes.

Usage: python3 scripts/gen-wallpaper.py [width] [height]
"""
import sys, math, random
from PIL import Image, ImageDraw, ImageFilter

W = int(sys.argv[1]) if len(sys.argv) > 1 else 2560
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1600
OUT = sys.argv[3] if len(sys.argv) > 3 else "quickshell/nothing/assets/wallpaper.png"

BASE = (196, 196, 196)
DARK = (150, 150, 150)
RED  = (215, 25, 33)
LINE = (168, 168, 168)

random.seed(1958)  # the year of Nothing... no, just a stable seed

img = Image.new("RGB", (W, H), BASE)
d = ImageDraw.Draw(img, "RGBA")

s = W / 2560  # scale factor


def r(x):
    return int(x * s)


# ── Composition ────────────────────────────────────────────────────────
# The left third stays empty: that is where the desktop widgets live.
# Without this the black cards sat on a grey rectangle and the whole
# thing became unreadable.
SAFE = 0.34  # reserved left fraction
x0 = int(W * SAFE)

d.rounded_rectangle([x0 + r(120), r(430), r(2400), r(1010)], radius=r(290),
                    fill=DARK + (255,))
d.rounded_rectangle([x0 + r(120), r(430), x0 + r(520), r(1010)], radius=r(40),
                    fill=DARK + (255,))
d.rounded_rectangle([x0 + r(60), r(1120), x0 + r(760), r(1420)], radius=r(150),
                    fill=(158, 158, 158, 255))

# ── The red disc, half hidden ──────────────────────────────────────────
d.pieslice([x0 + r(430), r(640), x0 + r(990), r(1200)], start=90, end=270,
           fill=RED + (255,))

# ── Crosshairs / construction lines ────────────────────────────────────
for y in (r(700), r(1180)):
    d.line([(x0 + r(900), y), (W, y)], fill=LINE + (200,), width=max(1, r(2)))
for x in (x0 + r(920), x0 + r(1780)):
    d.line([(x, r(540)), (x, r(1320))], fill=LINE + (200,), width=max(1, r(2)))
d.line([(x0 + r(600), r(760)), (x0 + r(830), r(760))],
       fill=(255, 255, 255, 220), width=max(1, r(3)))

# ── Very soft light gradient from the top-left corner ──────────────────
grad = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(grad)
for i in range(60):
    a = int(28 * (1 - i / 60))
    gd.ellipse([W * 0.05 - i * r(14), -H * 0.45 - i * r(14),
                W * 0.95 + i * r(14), H * 0.8 + i * r(14)], outline=a, width=r(30))
img = Image.composite(Image.new("RGB", (W, H), (214, 214, 214)), img,
                      grad.filter(ImageFilter.GaussianBlur(r(60))))

# ── Film grain ─────────────────────────────────────────────────────────
noise = Image.new("L", (W, H))
noise.putdata([random.gauss(128, 26).__int__() for _ in range(noise.width * noise.height)])
img = Image.blend(img, Image.merge("RGB", (noise, noise, noise)), 0.15)

# ── Subtle vignette ────────────────────────────────────────────────────
vig = Image.new("L", (W, H), 0)
ImageDraw.Draw(vig).ellipse([-W * 0.15, -H * 0.15, W * 1.15, H * 1.15], fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(r(180)))
img = Image.composite(img, Image.new("RGB", (W, H), (168, 168, 168)), vig)

img.save(OUT, optimize=True)
print(f"{OUT} - {W}x{H}")

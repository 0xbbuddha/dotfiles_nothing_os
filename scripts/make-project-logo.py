#!/usr/bin/env python3
"""Render assets/logo.png from the dot grid in config/fastfetch/logos/arch.txt.

Same derived-art reasoning as make-fetch-logos.py: the grid already is the
real Arch mark rasterised onto Nothing's dot matrix, so the project logo
is that grid redrawn as dots on a transparent canvas rather than a second,
hand-made take on the same shape.
"""
import os, re, sys
from PIL import Image, ImageDraw

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
SRC = os.path.join(ROOT, "config/fastfetch/logos/arch.txt")
OUT = os.path.join(ROOT, "assets/logo.png")

rows = [line for line in open(SRC, encoding="utf-8").read().splitlines() if line.strip()]
grid = [re.findall(r"\$([12])", row) for row in rows]
cols, count = len(grid[0]), len(grid)

CELL = 40
DOT = CELL * 0.62
PAD = CELL
GW, GH = cols * CELL, count * CELL
W, H = GW + PAD * 2, GH + PAD * 2

# A transparent canvas reads as white dots on nothing over a light
# GitHub theme - the matte black from Theme.qml's dark `surface` keeps
# the mark legible regardless of the reader's theme, same as the rice
# itself never adapting to a light background.
BG = (0x0b, 0x0b, 0x0b, 255)
LIT = (255, 255, 255, 255)
# The same $2 unlit tone fastfetch.jsonc uses, kept fully opaque: a
# translucent fill here doesn't blend with the black card underneath, it
# replaces those pixels outright, so the dot's real colour has to be
# baked in rather than left to whatever the PNG ends up composited over.
UNLIT = (0x26, 0x26, 0x26, 255)
RADIUS = CELL

im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
mask = Image.new("L", (W, H), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=RADIUS, fill=255)
bg = Image.new("RGBA", (W, H), BG)
im.paste(bg, (0, 0), mask)

d = ImageDraw.Draw(im)
for y, row in enumerate(grid):
    for x, v in enumerate(row):
        cx, cy = PAD + x * CELL + CELL / 2, PAD + y * CELL + CELL / 2
        r = DOT / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=LIT if v == "1" else UNLIT)

im.save(OUT)
print(f"  {OUT}  {W}x{H}")

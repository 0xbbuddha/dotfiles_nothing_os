#!/usr/bin/env python3
"""Rasterise the two fastfetch logos onto a dot grid. See the .sh wrapper."""
import io, os, re, subprocess, sys, tempfile
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
OUT = os.path.join(ROOT, "config/fastfetch/logos")
TMP = tempfile.mkdtemp(prefix="fetchlogo.")

def grid(svg_path, cols, rows, trim=False, square=False):
    """The shape as [[bool]] at grid resolution.

    Rendered once at a comfortable size, then cropped, centred and
    downsampled here rather than in ImageMagick: -extent crops instead of
    padding when the render is bigger than the canvas you name, and at
    density 900 it always is.
    """
    png = os.path.join(TMP, "g.png")
    subprocess.run(["magick", "-background", "none", "-density", "900", svg_path,
                    "-alpha", "extract", "-resize", "600x600", png], check=True)
    im = Image.open(png).convert("L")
    bb = im.point(lambda v: 255 if v > 100 else 0).getbbox()
    if bb:
        im = im.crop(bb)
    if square:
        # A symmetrical mark shows a one-dot offset immediately, and the
        # stock archlinux-logo.svg is not centred in its own viewBox.
        side = max(im.size)
        pad = Image.new("L", (side, side), 0)
        pad.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
        im = pad
    # BOX is an area average: each dot is lit by how much of it the shape
    # actually covers. Lanczos was tried first and rings, scattering lit
    # dots into the empty margin around the shape.
    im = im.resize((cols, rows), Image.BOX)
    g = [[im.getpixel((x, y)) > 128 for x in range(cols)] for y in range(rows)]
    if trim:
        while g and not any(g[0]):  g.pop(0)
        while g and not any(g[-1]): g.pop()
        while g and not any(r[0] for r in g):  g = [r[1:] for r in g]
        while g and not any(r[-1] for r in g): g = [r[:-1] for r in g]
    return g

def write(name, g):
    # $1 lit, $2 unlit. The unlit dots are kept: an unlit LED still shows
    # on a Nothing panel, and the grid is the point.
    art = "\n".join(" ".join("$1●" if c else "$2●" for c in row) for row in g)
    path = os.path.join(OUT, name)
    io.open(path, "w", encoding="utf-8").write(art + "\n")
    print(f"  {path}  {len(g[0])}x{len(g)}")

# ── Arch ──────────────────────────────────────────────────────────────
arch = "/usr/share/pixmaps/archlinux-logo.svg"
if os.path.exists(arch):
    write("arch.txt", grid(arch, 15, 15, square=True, trim=True))
else:
    print("  skipped arch.txt: no archlinux-logo.svg in /usr/share/pixmaps")

# ── Nothing ───────────────────────────────────────────────────────────
# Three shapes in one path. Each is shrunk about its own centre first:
# at this size the gaps between them are thinner than a dot, and without
# that the pill, the square and the circle merge into one blob.
qml = io.open(os.path.join(ROOT, "quickshell/nothing/components/NothingIcons.qml"),
              encoding="utf-8").read()
i = qml.index('"nothingLauncher": {')
depth = 0
for j in range(i, len(qml)):
    if qml[j] == "{": depth += 1
    elif qml[j] == "}":
        depth -= 1
        if depth == 0:
            blk = qml[i:j + 1]
            break
box = [float(v) for v in re.search(
    r"box:\s*\{\s*x:\s*([\d.]+),\s*y:\s*([\d.]+),\s*w:\s*([\d.]+),\s*h:\s*([\d.]+)",
    blk).groups()]
subs = ["M" + p for p in re.findall(r'd:\s*"([^"]+)"', blk)[0].split("M") if p.strip()]

def svg(bodies):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%g %g %g %g">%s</svg>'
            % (box[0], box[1], box[2], box[3], "".join(bodies)))

def bounds(sub):
    p = os.path.join(TMP, "one.svg")
    io.open(p, "w").write(svg(['<path fill="#fff" d="%s"/>' % sub]))
    q = os.path.join(TMP, "one.pgm")
    subprocess.run(["magick", "-background", "none", "-density", "900", p,
                    "-alpha", "extract", "-resize", "400x!", q], check=True)
    im = Image.open(q).convert("L")
    bb = im.point(lambda v: 255 if v > 100 else 0).getbbox()
    w, h = im.size
    return (box[0] + bb[0] / w * box[2], box[1] + bb[1] / h * box[3],
            box[0] + bb[2] / w * box[2], box[1] + bb[3] / h * box[3])

SHRINK = 0.84
bodies = []
for sub in subs:
    x0, y0, x1, y1 = bounds(sub)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bodies.append('<g transform="translate(%g,%g) scale(%g) translate(%g,%g)">'
                  '<path fill="#fff" d="%s"/></g>' % (cx, cy, SHRINK, -cx, -cy, sub))
p = os.path.join(TMP, "nothing.svg")
io.open(p, "w").write(svg(bodies))
write("nothing.txt", grid(p, 14, 18, trim=True))

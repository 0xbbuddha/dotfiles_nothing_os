#!/usr/bin/env python3
"""Turn any picture into a Nothing-style dot-matrix wallpaper.

    scripts/dot-wallpaper.py in.png out.png
    scripts/dot-wallpaper.py in.png out.png --size 1920x1080 --circle

Black ground, a dot grid, and exactly one colour beside white: the red is
kept where the source is genuinely red, so the accent comes out of the
picture rather than being painted onto it.

The signal driving each dot is distance from the picture's own paper
colour, not luminance. Luminance does not work on a drawing: read
straight, light paper becomes a solid white disc and the artwork
disappears inside it; read inverted, black hair becomes a white blob.
What a dot panel should light is the ink, so that is what is measured.

No image is shipped with this. Point it at your own.
"""
import argparse
import math
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BG    = (11, 11, 11)
WHITE = (255, 255, 255)
RED   = (215, 25, 33)
UNLIT    = (32, 32, 32)
GRID_MIN = 26      # an unlit dot far from the figure
GRID_MAX = 96      # an unlit dot right beside it
RAY_MAX  = 150     # a dot on a concentration line
NDOT  = "/usr/share/fonts/TTF/Ndot77JPExtended.ttf"
MONO  = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"


def paper_colour(rgb, alpha):
    """The picture's own background: the colour it uses most.

    Sampling near the edge was tried first and is wrong on a portrait:
    hair runs off the top of the frame, the samples come back black, and
    with black taken for paper every other dot counts as ink and the
    whole panel lights up.
    """
    small = rgb.resize((96, 96), Image.BOX)
    a = alpha.resize((96, 96), Image.BOX)
    tally = {}
    for y in range(96):
        for x in range(96):
            if a.getpixel((x, y)) < 200:
                continue
            r, g, b = small.getpixel((x, y))
            hit = tally.setdefault((r // 16, g // 16, b // 16), [0, 0, 0, 0])
            hit[0] += 1
            hit[1] += r
            hit[2] += g
            hit[3] += b
    if not tally:
        return (255, 255, 255)
    n, r, g, b = max(tally.values(), key=lambda v: v[0])
    return (r // n, g // n, b // n)


def build(src_path, out, W, H, pitch, subject_h, cx, cy, label, sub,
          gain, red_at, floor, circle, halo, grid, specs, rays, jp):
    src = Image.open(src_path).convert("RGBA")

    if circle:
        # A sticker-style badge carries a soft shadow outside its disc,
        # and a shadow is a long way from paper, so every dot of it lit
        # up. Clipping to the inscribed circle removes it at the source.
        w, h = src.size
        mask = Image.new("L", (w, h), 0)
        r = min(w, h) * 0.495
        ImageDraw.Draw(mask).ellipse(
            [w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=255)
        src.putalpha(Image.composite(src.split()[3],
                                     Image.new("L", (w, h), 0), mask))

    target_h = int(H * subject_h)
    scale = target_h / src.size[1]
    src = src.resize((max(1, int(src.size[0] * scale)), target_h), Image.LANCZOS)

    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    plate.alpha_composite(src, (int(W * cx - src.size[0] / 2),
                                int(H * cy - src.size[1] / 2)))

    paper = paper_colour(plate.convert("RGB"), plate.split()[3])
    far = max(1.0, sum(c * c for c in paper) ** 0.5)

    cols, rows = W // pitch, H // pitch
    # One area average per cell. Point sampling a line drawing turns fine
    # linework into noise.
    small = plate.resize((cols, rows), Image.BOX)
    rgb = small.convert("RGB")
    alpha = small.split()[3]

    # The empty half of a wallpaper should not be empty, it should be an
    # unlit panel. A heavy blur of the subject's own mask gives a field
    # that brightens the grid near the figure and fades out into the
    # corners, so the dots read as one surface rather than as a drawing
    # dropped onto black.
    field = alpha.filter(ImageFilter.GaussianBlur(radius=max(3, cols // 9)))
    fmax = max(1, field.getextrema()[1])

    # Concentration lines. A manga draws attention by converging the
    # whole frame on one point, and it is the one piece of that language
    # that survives being made of dots: the lines are already a lattice
    # of marks, and here they simply light cells the grid already has.
    #
    # Irregular on purpose. Evenly spaced rays read as a machine part,
    # and a screentone sheet never looks like that.
    import random
    rng = random.Random(1958)
    ray_at = []
    if rays > 0:
        step = 2 * math.pi / rays
        for i in range(rays):
            ray_at.append((i * step + rng.uniform(-0.34, 0.34) * step,
                           rng.uniform(0.55, 1.0)))
        ray_at.sort()
    focus = (W * cx, H * cy)

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    rmax = pitch * 0.46

    for gy in range(rows):
        for gx in range(cols):
            x = gx * pitch + pitch / 2
            y = gy * pitch + pitch / 2
            a = alpha.getpixel((gx, gy))
            r, g, b = rgb.getpixel((gx, gy))

            lit, colour = 0.0, WHITE
            if a > 20:
                dist = ((r - paper[0]) ** 2 + (g - paper[1]) ** 2
                        + (b - paper[2]) ** 2) ** 0.5 / far
                # A dead zone around the paper colour: a background is
                # rarely perfectly flat, and without this its vignette
                # fogs the empty half of the screen.
                dist = max(0.0, dist - floor) / max(1e-6, 1.0 - floor)
                lit = min(1.0, dist * gain) * (a / 255)
                if (r - max(g, b)) / 255 > red_at:
                    colour = RED
                    lit = max(lit, 0.55)

            rad = rmax * lit
            if rad < 0.9:
                # The unlit grid stays visible: on a Nothing panel an
                # unlit LED is still a dot. Its brightness follows the
                # halo, so the panel glows around the figure.
                raw = (field.getpixel((gx, gy)) / fmax) ** 0.7
                # The glow belongs outside the silhouette. Inside it, the
                # unlit cells are the face, and that has to stay black or
                # the negative space the whole picture is built on turns
                # into grey mud.
                near = raw * (1.0 - a / 255.0)
                v = int(GRID_MIN + (GRID_MAX - GRID_MIN) * min(1.0, near * halo))
                r0 = 0.9 + grid * (0.5 + 1.5 * near)

                if ray_at:
                    dx, dy = x - focus[0], y - focus[1]
                    dist = math.hypot(dx, dy)
                    # The blurred subject mask doubles as the keep-out:
                    # the lines stop where the figure starts, which is
                    # where a drawn one would stop too.
                    gate = max(0.0, 1.0 - raw * 2.1)
                    # Strongest just off the figure, gone before the
                    # corners. Run at full strength to the frame and they
                    # stop being concentration lines and become scan
                    # lines, and they trample the type in the margin.
                    reach = math.hypot(W, H) * 0.42
                    fade = max(0.0, 1.0 - max(0.0, dist - reach) / (reach * 0.9))
                    if dist > pitch * 4 and gate > 0.02 and fade > 0.02:
                        th = math.atan2(dy, dx) % (2 * math.pi)
                        best = 9.9
                        weight = 0.0
                        for a, wgt in ray_at:
                            delta = abs(th - a)
                            delta = min(delta, 2 * math.pi - delta)
                            if delta < best:
                                best, weight = delta, wgt
                        # Constant width in pixels, so the lines converge
                        # on the focus instead of fanning out from it.
                        half = pitch * 0.62
                        across = best * dist
                        if across < half:
                            k = (1.0 - across / half) * weight * gate * fade
                            v = max(v, int(GRID_MIN + (RAY_MAX - GRID_MIN) * k))
                            r0 = max(r0, 0.9 + grid * 1.7 * k)

                d.ellipse([x - r0, y - r0, x + r0, y + r0], fill=(v, v, v))
            else:
                d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=colour)

    # ── The block on the empty side ───────────────────────────────────
    # A wordmark alone leaves half a wallpaper doing nothing. What fills
    # it here is the furniture Nothing puts around its own type: hairline
    # rules, tracked capitals at a size you read only if you look, and
    # one red mark. Nothing louder, or it stops being the same object as
    # the desktop it sits behind.
    x0 = int(W * 0.06)
    rule_w = int(W * 0.26)
    rule = (38, 38, 38)

    def hair(y):
        d.line([x0, int(H * y), x0 + rule_w, int(H * y)], fill=rule, width=1)

    hair(0.705)
    # The one red thing on the page, and it is 8 pixels wide.
    d.rectangle([x0, int(H * 0.705) - 3, x0 + int(W * 0.004), int(H * 0.705) + 3],
                fill=RED)

    if label:
        d.text((x0, int(H * 0.735)), label,
               font=ImageFont.truetype(NDOT, int(H * 0.055)), fill=WHITE)
    if sub:
        d.text((x0 + 2, int(H * 0.808)), sub,
               font=ImageFont.truetype(MONO, int(H * 0.0125)), fill=(120, 120, 120))

    hair(0.845)

    small = ImageFont.truetype(MONO, int(H * 0.0115))
    for i, line in enumerate(specs):
        d.text((x0 + 2, int(H * (0.862 + i * 0.023))), line,
               font=small, fill=(88, 88, 88))

    # Vertical Japanese, set in the same face as the wordmark. Ndot77JP
    # carries 21771 glyphs, so this is Nothing's own dot type rather than
    # a fallback pretending to be it, and a column running downward is
    # how a panel is captioned.
    if jp:
        size = int(H * 0.058)
        jf = ImageFont.truetype(NDOT, size)
        jx = int(W * 0.072)
        jy = int(H * 0.115)
        d.line([jx - int(W * 0.016), jy, jx - int(W * 0.016),
                jy + int(size * 1.30 * len(jp))], fill=rule, width=1)
        for i, ch in enumerate(jp):
            d.text((jx, jy + int(i * size * 1.30)), ch, font=jf, fill=(205, 205, 205))

    # Registration marks, the way a print sheet is cornered. They give the
    # frame an edge without drawing a border around the whole screen.
    m = int(W * 0.022)
    inset = int(W * 0.028)
    for cx_, cy_, sx, sy in ((inset, inset, 1, 1), (W - inset, inset, -1, 1),
                             (inset, H - inset, 1, -1), (W - inset, H - inset, -1, -1)):
        d.line([cx_, cy_, cx_ + sx * m, cy_], fill=rule, width=1)
        d.line([cx_, cy_, cx_, cy_ + sy * m], fill=rule, width=1)

    img.save(out)
    print("%s  %dx%d  paper %s" % (out, W, H, paper))


def aspect_label(W, H):
    """16:10, not 8:5. Both are the same fraction; only one is what a
    screen is sold as."""
    from math import gcd
    g = gcd(W, H)
    a, b = W // g, H // g
    for na, nb in ((16, 10), (16, 9), (21, 9), (4, 3), (3, 2), (5, 4), (32, 9)):
        if a * nb == b * na:
            return "%d : %d" % (na, nb)
    return "%d : %d" % (a, b)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("source")
    p.add_argument("out")
    p.add_argument("--size", default="1920x1200", help="WxH, default 1920x1200")
    p.add_argument("--pitch", type=int, default=9, help="dot spacing in px")
    p.add_argument("--scale", type=float, default=0.95,
                   help="subject height as a share of the screen")
    p.add_argument("--x", type=float, default=0.70, help="subject centre, 0..1")
    p.add_argument("--y", type=float, default=0.50, help="subject centre, 0..1")
    p.add_argument("--label", default="N O T H I N G")
    p.add_argument("--sub", default="")
    p.add_argument("--gain", type=float, default=2.6)
    p.add_argument("--red-at", type=float, default=0.30,
                   help="how red a pixel must be to stay red")
    p.add_argument("--floor", type=float, default=0.09,
                   help="dead zone around the paper colour")
    p.add_argument("--circle", action="store_true",
                   help="clip the source to its inscribed circle first")
    p.add_argument("--halo", type=float, default=1.0,
                   help="how far the unlit grid brightens around the figure")
    p.add_argument("--grid", type=float, default=1.0,
                   help="size of the unlit dots")
    p.add_argument("--spec", action="append", default=[],
                   help="a line for the small block, repeatable")
    p.add_argument("--rays", type=int, default=64,
                   help="manga concentration lines, 0 for none")
    p.add_argument("--jp", default="ナッシング",
                   help="vertical Japanese column, empty for none")
    a = p.parse_args()

    try:
        W, H = (int(v) for v in a.size.lower().split("x"))
    except ValueError:
        sys.exit("--size wants WxH, for example 1920x1080")

    specs = a.spec or ["%d  x  %d" % (W, H), aspect_label(W, H),
                       "D O T   M A T R I X"]
    build(a.source, a.out, W, H, a.pitch, a.scale, a.x, a.y,
          a.label, a.sub, a.gain, a.red_at, a.floor, a.circle,
          a.halo, a.grid, specs, a.rays, a.jp)


if __name__ == "__main__":
    main()

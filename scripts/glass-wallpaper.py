#!/usr/bin/env python3
"""Run a picture through Nothing's reeded-glass wallpaper filter.

    scripts/glass-wallpaper.py in.png out.png
    scripts/glass-wallpaper.py in.png out.png --size 1920x1080 --strength 30

Nothing OS's "Glass" wallpaper style looks like the picture is seen
through fluted glass: vertical ribs, each one shifted and lensed on its
own, with a highlight down its centre and a groove at its edge. Baked
into a PNG rather than drawn live - a wallpaper does not move, so there
is nothing here a shader would buy that is worth the GPU risk.

No image is shipped with this. Point it at your own.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image


def cover_crop(img, W, H):
    """Resize to cover WxH, then centre-crop. Same idea as CSS's
    background-size: cover - no letterboxing, no stretch."""
    sw, sh = img.size
    scale = max(W / sw, H / sh)
    nw, nh = max(W, round(sw * scale)), max(H, round(sh * scale))
    img = img.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - W) // 2, (nh - H) // 2
    return img.crop((left, top, left + W, top + H))


def build(src_path, out, W, H, rib, strength, seed):
    img = cover_crop(Image.open(src_path).convert("RGB"), W, H)
    arr = np.asarray(img, dtype=np.float32)

    ribs = max(1, W // rib)
    cols = np.arange(W)
    rib_of = np.minimum(cols // rib, ribs - 1)
    # 0..1 across the rib's own width, not the image's - each rib is its
    # own little lens.
    local = (cols % rib) / max(1, rib - 1)

    # Each rib sits at its own depth in the glass: a flat random offset
    # per rib, not a smooth wave, which is what makes the ribs read as
    # separate pieces instead of one wavy sheet.
    rng = np.random.default_rng(seed)
    base_shift = rng.uniform(-strength, strength, size=ribs)

    # Within a rib, a small extra shift bowed across its width - the
    # lens itself, bending more at the centre than at the seam where it
    # meets its neighbour.
    lens_shift = np.sin(local * np.pi) * (strength * 0.3)

    shift = base_shift[rib_of] + lens_shift

    y = np.arange(H)[:, None]
    src_y = np.clip(np.round(y - shift[None, :]), 0, H - 1).astype(np.int32)
    col_idx = np.broadcast_to(cols, (H, W))
    out_arr = arr[src_y, col_idx]

    # The highlight a rounded rib catches: bright at its centre, dim at
    # its seam. Squared so the falloff is steep near the edge rather
    # than linear, the way light actually concentrates on a curve.
    centred = local * 2 - 1
    highlight = (1.0 - centred ** 2) ** 1.5
    shade = 0.78 + 0.34 * highlight
    out_arr *= shade[None, :, None]

    # The groove between two ribs, one pixel wide, slightly short of
    # the full rib width so it never lands on the same column as the
    # next rib's own groove at rib=0.
    groove = (cols % rib) == 0
    out_arr[:, groove, :] *= 0.72

    out_arr = np.clip(out_arr, 0, 255).astype(np.uint8)
    out_dir = os.path.dirname(os.path.abspath(out))
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(out_arr, "RGB").save(out)
    print("%s  %dx%d  %d ribs" % (out, W, H, ribs))


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("source")
    p.add_argument("out")
    p.add_argument("--size", default="1920x1200", help="WxH, default 1920x1200")
    p.add_argument("--rib", type=int, default=16,
                   help="width of one glass rib in px, default 16")
    p.add_argument("--strength", type=float, default=18,
                   help="max vertical shift in px, default 18")
    p.add_argument("--seed", type=int, default=1958,
                   help="which ribs land where - same seed, same glass")
    a = p.parse_args()

    try:
        W, H = (int(v) for v in a.size.lower().split("x"))
    except ValueError:
        sys.exit("--size wants WxH, for example 1920x1080")
    if a.rib < 2:
        sys.exit("--rib must be at least 2px")

    build(a.source, a.out, W, H, a.rib, a.strength, a.seed)


if __name__ == "__main__":
    main()

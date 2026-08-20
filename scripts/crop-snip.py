#!/usr/bin/env python3
"""Crop a frozen grim capture. Avoids re-grimming the dimmed overlay."""
from __future__ import annotations

import sys

import cv2


def main() -> int:
    if len(sys.argv) != 4:
        return 1
    src, dst, geo = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        xy, wh = geo.split()
        x, y = (int(round(float(v))) for v in xy.split(","))
        w, h = (int(round(float(v))) for v in wh.split("x"))
    except ValueError:
        return 1
    img = cv2.imread(src, cv2.IMREAD_UNCHANGED)
    if img is None:
        return 1
    ih, iw = img.shape[:2]
    x = max(0, min(x, iw - 1))
    y = max(0, min(y, ih - 1))
    w = max(1, min(w, iw - x))
    h = max(1, min(h, ih - y))
    crop = img[y : y + h, x : x + w]
    if crop.size == 0:
        return 1
    return 0 if cv2.imwrite(dst, crop) else 1


if __name__ == "__main__":
    sys.exit(main())

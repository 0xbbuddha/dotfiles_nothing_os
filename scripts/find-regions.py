#!/usr/bin/env python3
"""Detect visual blocks in a screenshot (cards, images, panels).

Without opencv-contrib: no selective search. Use contours after Canny,
which is enough to highlight what we click.
"""
from __future__ import annotations

import argparse
import json
import sys

import cv2
import numpy as np


def iou(a: dict, b: dict) -> float:
    xA = max(a["x"], b["x"])
    yA = max(a["y"], b["y"])
    xB = min(a["x"] + a["width"], b["x"] + b["width"])
    yB = min(a["y"] + a["height"], b["y"] + b["height"])
    inter = max(0, xB - xA) * max(0, yB - yA)
    union = a["width"] * a["height"] + b["width"] * b["height"] - inter
    return inter / union if union else 0.0


def nms(regions: list[dict], threshold: float = 0.55) -> list[dict]:
    regions = sorted(regions, key=lambda r: r["width"] * r["height"])
    keep: list[dict] = []
    while regions:
        cur = regions.pop(0)
        keep.append(cur)
        regions = [r for r in regions if iou(cur, r) < threshold]
    return keep


def find_regions(
    image: np.ndarray,
    min_width: int,
    min_height: int,
    max_width: int | None,
    max_height: int | None,
    resize: float,
) -> list[dict]:
    orig_h, orig_w = image.shape[:2]
    small = cv2.resize(
        image,
        (max(1, int(orig_w * resize)), max(1, int(orig_h * resize))),
        interpolation=cv2.INTER_AREA,
    )
    gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blur, 40, 120)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    edges = cv2.dilate(edges, kernel, iterations=1)
    edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel, iterations=1)

    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    regions: list[dict] = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if resize != 1.0:
            x, y, w, h = (int(v / resize) for v in (x, y, w, h))
        if w >= orig_w - 4 and h >= orig_h - 4:
            continue
        if w < min_width or h < min_height:
            continue
        if max_width is not None and w >= max_width:
            continue
        if max_height is not None and h >= max_height:
            continue
        aspect = w / max(h, 1)
        if aspect > 10 or aspect < 0.08:
            continue
        regions.append({"x": x, "y": y, "width": w, "height": h})
    return nms(regions)[:28]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("-i", "--image", required=True)
    p.add_argument("--min-width", type=int, default=90)
    p.add_argument("--min-height", type=int, default=70)
    p.add_argument("--max-width", type=int)
    p.add_argument("--max-height", type=int)
    p.add_argument("--resize-factor", type=float, default=0.28)
    p.add_argument("--hyprctl", action="store_true")
    args = p.parse_args()

    image = cv2.imread(args.image)
    if image is None:
        print("[]")
        return 0

    regions = find_regions(
        image,
        args.min_width,
        args.min_height,
        args.max_width,
        args.max_height,
        args.resize_factor,
    )
    if args.hyprctl:
        out = [{"at": [r["x"], r["y"]], "size": [r["width"], r["height"]]} for r in regions]
    else:
        out = regions
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())

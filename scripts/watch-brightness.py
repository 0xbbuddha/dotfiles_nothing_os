#!/usr/bin/env python3
"""Emit `kind,device,current,max` whenever a sysfs light changes.

Two families:
  backlight  laptop panel (/sys/class/backlight)
  kbd        keyboard backlight (*kbd_backlight* under /sys/class/leds)

inotify does not work on /sys: we re-read the files, 20 times per second.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

BL = Path("/sys/class/backlight")
LEDS = Path("/sys/class/leds")
prev: dict[tuple[str, str], str] = {}


def iter_devs() -> list[tuple[str, Path]]:
    out: list[tuple[str, Path]] = []
    try:
        out.extend(("backlight", p) for p in BL.iterdir() if p.is_dir())
    except OSError:
        pass
    try:
        out.extend(
            ("kbd", p)
            for p in LEDS.iterdir()
            if p.is_dir() and "kbd_backlight" in p.name
        )
    except OSError:
        pass
    return out


while True:
    for kind, dev in iter_devs():
        try:
            cur = (dev / "brightness").read_text().strip()
            mx = (dev / "max_brightness").read_text().strip()
        except OSError:
            continue
        key = (kind, dev.name)
        if prev.get(key) != cur:
            prev[key] = cur
            sys.stdout.write(f"{kind},{dev.name},{cur},{mx}\n")
            sys.stdout.flush()
    time.sleep(0.05)

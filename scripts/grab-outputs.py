#!/usr/bin/env python3
"""Grim each output to /tmp/nothing-snip/<name>.png, before the overlay."""
from __future__ import annotations

import json
import os
import subprocess
import sys

OUT = "/tmp/nothing-snip"


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    try:
        mon = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"]))
    except (OSError, json.JSONDecodeError):
        return 1
    procs = []
    for m in mon:
        name = m.get("name")
        if not name:
            continue
        procs.append(subprocess.Popen(
            ["grim", "-o", name, os.path.join(OUT, f"{name}.png")],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ))
    return 1 if any(p.wait() != 0 for p in procs) else 0


if __name__ == "__main__":
    sys.exit(main())

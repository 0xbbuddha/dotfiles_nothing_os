#!/usr/bin/env python3
"""Grim each output to $XDG_RUNTIME_DIR/nothing-snip/<name>.png, before the overlay."""
from __future__ import annotations

import json
import os
import stat
import subprocess
import sys

RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
OUT = os.path.join(RUNTIME, "nothing-snip")


def private_dir(path: str) -> bool:
    try:
        os.mkdir(path, 0o700)
    except FileExistsError:
        pass
    except OSError:
        return False
    info = os.lstat(path)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        return False
    os.chmod(path, 0o700)
    return True


def main() -> int:
    os.umask(0o077)
    if not private_dir(OUT):
        return 1
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

#!/usr/bin/env python3
"""Print the shell's accent color as 6 plain hex digits (no '#', original
case), or nothing if config.json has none set or it isn't a valid color.

Shared by apply-spicetify.sh and apply-zen-theme.sh, which used to each
carry their own copy of this exact read-and-validate step - and had
already drifted on the formatting (one uppercased, the other lowercased
and re-added '#'). That formatting is still each caller's own job: it
differs for a real reason (spicetify's color.ini wants bare uppercase
hex, Zen's CSS wants a lowercase '#rrggbb'), so only the shared part -
reading the file and validating the color - lives here.

Usage: read-accent.py <config.json>
"""
import json
import re
import sys

accent = ""
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    a = d.get("accent", "") or ""
    if re.fullmatch(r"#?[0-9a-fA-F]{6}", a):
        accent = a.lstrip("#")
except Exception:
    pass
print(accent)

#!/usr/bin/env python3
"""Dump name<TAB>file://path for the active icon pack.

When the shell style is Nothing, Lawnicons squircles in
~/.local/share/icons/Nothing win over Qogir vendor logos.
"""
import os
import sys

theme = sys.argv[1] if len(sys.argv) > 1 else "Qogir-Dark"
style = sys.argv[2] if len(sys.argv) > 2 else theme
home = os.path.expanduser("~")

roots = []
if style == "Nothing":
    roots.append(os.path.join(home, ".local/share/icons/Nothing"))
roots += [
    f"/usr/share/icons/{theme}",
    os.path.expanduser(f"~/.local/share/icons/{theme}"),
]

subs = [
    "scalable/apps",
    "scalable@2x/apps",
    "128/apps",
    "48/apps",
    "48x48/apps",
    "apps",
]
out = {}
for root in roots:
    for sub in subs:
        d = os.path.join(root, sub)
        if not os.path.isdir(d):
            continue
        try:
            names = os.listdir(d)
        except OSError:
            continue
        for fn in names:
            if not (fn.endswith(".svg") or fn.endswith(".png")):
                continue
            key = fn.rsplit(".", 1)[0].lower()
            path = "file://" + os.path.join(d, fn)
            prev = out.get(key, "")
            if prev:
                continue
            out[key] = path

for key, path in out.items():
    print(f"{key}\t{path}")

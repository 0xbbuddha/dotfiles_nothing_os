#!/usr/bin/env python3
"""Default applications per kind of file, for Settings > Dock > Default apps.

    mime-defaults.py list            JSON: every category, its current app
                                     and the installed apps that declare it
    mime-defaults.py get <category> [--user]
                                     the .desktop id currently set (or "");
                                     --user: only ~/.config/mimeapps.list
    mime-defaults.py set <category> <desktop-id>

Writes only the [Default Applications] lines of ~/.config/mimeapps.list for
the category's MIME types, the file xdg-open, portals and file managers
read, editing lines in place: comments, order and every other line and
section are kept as they were. The previous file is copied to
mimeapps.list.bak-nothing the first time. An id that does not
declare the category's types is refused, so nothing here can point PDFs
at a program that cannot open them.
"""
import configparser
import json
import os
import shutil
import sys
import tempfile

CATEGORIES = [
    ("web", "Web browser", ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"]),
    ("mail", "Email", ["x-scheme-handler/mailto"]),
    ("files", "Folders", ["inode/directory"]),
    ("pdf", "PDF", ["application/pdf"]),
    ("image", "Images", ["image/png", "image/jpeg", "image/gif", "image/webp", "image/avif", "image/bmp"]),
    ("video", "Video", ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"]),
    ("audio", "Music", ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4", "audio/opus"]),
    ("text", "Text", ["text/plain", "text/markdown", "application/json"]),
    ("archive", "Archives", ["application/zip", "application/x-7z-compressed", "application/x-tar",
                             "application/vnd.rar", "application/x-compressed-tar"]),
]
BY_KEY = {k: (label, mimes) for k, label, mimes in CATEGORIES}

HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local/share")
DATA_DIRS = [DATA_HOME] + (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":")
DATA_DIRS += [os.path.join(HOME, ".local/share/flatpak/exports/share"), "/var/lib/flatpak/exports/share"]
MIMEAPPS = os.path.join(CONFIG, "mimeapps.list")


def parser():
    p = configparser.ConfigParser(interpolation=None, strict=False, delimiters=("=",))
    p.optionxform = str  # MIME types and ids are case-sensitive
    return p


def desktop_entries():
    """id -> (name, set of MIME types), first one found wins (XDG order)."""
    out = {}
    for base in DATA_DIRS:
        root = os.path.join(base, "applications")
        if not os.path.isdir(root):
            continue
        for dirpath, _, files in os.walk(root):
            for f in files:
                if not f.endswith(".desktop"):
                    continue
                path = os.path.join(dirpath, f)
                # applications/kde/foo.desktop has the id kde-foo.desktop
                did = os.path.relpath(path, root).replace(os.sep, "-")
                if did in out:
                    continue
                p = parser()
                try:
                    p.read(path, encoding="utf-8")
                    e = p["Desktop Entry"]
                except Exception:
                    continue
                if e.get("NoDisplay", "false") == "true" or e.get("Hidden", "false") == "true":
                    continue
                if e.get("Type", "Application") != "Application":
                    continue
                mimes = {m for m in e.get("MimeType", "").split(";") if m}
                out[did] = (e.get("Name", did[:-8]), mimes)
    return out


def current_defaults(user_only=False):
    """mimetype -> first id from mimeapps.list files (user, then system)."""
    found = {}
    files = [MIMEAPPS]
    if not user_only:
        files += [os.path.join(CONFIG, "hyprland-mimeapps.list")]
        files += [os.path.join(d, "applications/mimeapps.list") for d in DATA_DIRS]
    for path in files:
        if not os.path.isfile(path):
            continue
        p = parser()
        try:
            p.read(path, encoding="utf-8")
        except Exception:
            continue
        if not p.has_section("Default Applications"):
            continue
        for mime, ids in p["Default Applications"].items():
            first = next((i for i in ids.split(";") if i), "")
            found.setdefault(mime, first)
    return found


def cmd_list():
    apps = desktop_entries()
    cur = current_defaults()
    result = []
    for key, label, mimes in CATEGORIES:
        cands = sorted(((i, n) for i, (n, m) in apps.items() if m & set(mimes)),
                       key=lambda x: x[1].lower())
        current = next((cur[m] for m in mimes if cur.get(m)), "")
        result.append({
            "key": key, "label": label, "mimes": mimes, "current": current,
            "currentName": apps.get(current, (current[:-8] if current else "",))[0],
            "candidates": [{"id": i, "name": n} for i, n in cands],
        })
    print(json.dumps(result))


def cmd_get(key, user_only=False):
    if key not in BY_KEY:
        sys.exit("unknown category")
    cur = current_defaults(user_only)
    print(next((cur[m] for m in BY_KEY[key][1] if cur.get(m)), ""))


def set_defaults(lines, want):
    """The file's lines with `want` (mime -> value) set in [Default
    Applications]. Line-based on purpose: comments, ordering, repeated
    sections and every other line stay exactly as they were."""
    out, section, done, first_end = [], None, set(), None
    for line in lines:
        st = line.strip()
        if st.startswith("[") and st.endswith("]"):
            if section == "Default Applications" and first_end is None:
                first_end = len(out)
            section = st[1:-1]
        elif section == "Default Applications" and "=" in st and not st.startswith("#"):
            key = st.split("=", 1)[0].strip()
            if key in want:
                if key in done:
                    continue            # a duplicate would shadow the choice
                out.append(f"{key}={want[key]}")
                done.add(key)
                continue
        out.append(line)
    if section == "Default Applications" and first_end is None:
        first_end = len(out)
    missing = [f"{k}={v}" for k, v in want.items() if k not in done]
    if missing:
        if first_end is None:
            if out and out[-1].strip():
                out.append("")
            out += ["[Default Applications]"] + missing
        else:
            # Before any blank lines that end that section.
            at = first_end
            while at > 0 and not out[at - 1].strip():
                at -= 1
            out[at:at] = missing
    return out


def write_file(path, lines):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".mimeapps.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, path)


def cmd_set(key, did):
    if key not in BY_KEY:
        sys.exit("unknown category")
    apps = desktop_entries()
    _, mimes = BY_KEY[key]
    if did not in apps or not (apps[did][1] & set(mimes)):
        sys.exit(f"{did} does not open {BY_KEY[key][0].lower()}")
    os.makedirs(CONFIG, exist_ok=True)
    if os.path.isfile(MIMEAPPS) and not os.path.exists(MIMEAPPS + ".bak-nothing"):
        shutil.copy2(MIMEAPPS, MIMEAPPS + ".bak-nothing")
    # Only the types this app declares: a viewer that handles PNG but not
    # AVIF keeps the old default for AVIF instead of breaking it.
    want = {m: did + ";" for m in mimes if m in apps[did][1]}
    lines = []
    if os.path.isfile(MIMEAPPS):
        with open(MIMEAPPS, encoding="utf-8") as f:
            lines = f.read().splitlines()
    write_file(MIMEAPPS, set_defaults(lines, want))
    print("ok")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["list"]:
        cmd_list()
    elif len(a) in (2, 3) and a[0] == "get":
        cmd_get(a[1], a[2:] == ["--user"])
    elif len(a) == 3 and a[0] == "set":
        cmd_set(a[1], a[2])
    else:
        sys.exit(__doc__)

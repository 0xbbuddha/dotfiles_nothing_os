#!/usr/bin/env python3
"""Build the Nothing icon theme.

1. Lawnicons (Apache-2.0) - outline glyphs, when a matching drawable exists.
2. Every other app icon found on the system (Qogir, hicolor, pixmaps) is
   converted to a white silhouette on a dark squircle. No per-app list:
   if an application has an icon, it gets a Nothing version.

Usage:
  scripts/build-nothing-icons.py [DEST_DIR] [--force]
"""
from __future__ import annotations

import io
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image as PILImage
from PIL import ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / ".cache/nothing/lawnicons/svgs"
args = [a for a in sys.argv[1:] if a != "--force"]
FORCE = "--force" in sys.argv[1:]
DEST = Path(args[0]) if args else Path.home() / ".local/share/icons/Nothing"
APPS = DEST / "scalable/apps"
RASTER = DEST / "128/apps"

# Lawnicons quality override for Linux names (Android drawables).
# Coverage of everything else is fill_from_system(), not this table.
ALIASES = {
    "spotify-client": "spotify",
    "vesktop": "discord",
    "discord": "discord",
    "google-chrome": "google_chrome",
    "com.google.chrome": "google_chrome",
    "chromium": "google_chrome",
    "kitty": "terminal",
    "alacritty": "terminal",
    "foot": "terminal",
    "org.kde.konsole": "terminal",
    "konsole": "terminal",
    "code": "code_editor",
    "code-oss": "code_editor",
    "helium": "internet_browser",
    "helium-browser": "internet_browser",
    "dolphin": "file_manager",
    "org.kde.dolphin": "file_manager",
    "nautilus": "file_manager",
    "org.gnome.nautilus": "file_manager",
    "thunar": "file_manager",
    "org.xfce.thunar": "file_manager",
    "pcmanfm": "file_manager",
    "nemo": "file_manager",
    "telegram": "telegram",
    "org.telegram.desktop": "telegram",
    "steam": "steam",
    "com.valvesoftware.Steam": "steam",
    "vlc": "vlc",
    "org.videolan.vlc": "vlc",
    "firefox-esr": "firefox",
    "org.mozilla.firefox": "firefox",
}

INDEX = """[Icon Theme]
Name=Nothing
Comment=Nothing OS - white glyphs on dark squircles
Inherits=hicolor
DisplayDepth=32
Example=folder
FollowsColorScheme=false

DesktopDefault=48
DesktopSizes=16,22,32,48,64,128,256
ToolbarDefault=22
ToolbarSizes=16,22,32,48
MainToolbarDefault=22
MainToolbarSizes=16,22,32,48
SmallDefault=16
SmallSizes=16,22,32,48
PanelDefault=48
PanelSizes=16,22,32,48,64,128,256
DialogDefault=32
DialogSizes=16,22,32,48,64,128,256

Directories=scalable/apps,scalable/places,128/apps,128/places,128/mimetypes,22/actions

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=16
MaxSize=512

[128/apps]
Size=128
Context=Applications
Type=Fixed

[scalable/places]
Size=128
Context=Places
Type=Scalable
MinSize=16
MaxSize=256

[128/places]
Size=128
Context=Places
Type=Scalable
MinSize=16
MaxSize=256

[128/mimetypes]
Size=128
Context=MimeTypes
Type=Scalable
MinSize=16
MaxSize=256

[22/actions]
Size=22
Context=Actions
Type=Fixed
"""

INNER_RE = re.compile(r"<svg\b[^>]*>(.*)</svg>", re.I | re.S)
VB_RE = re.compile(r'viewBox="([^"]+)"', re.I)

ICON_DIRS = [
    Path("/usr/share/icons/Qogir-Dark/scalable/apps"),
    Path("/usr/share/icons/Qogir-Dark/128/apps"),
    Path("/usr/share/icons/Qogir-Dark/48/apps"),
    Path("/usr/share/icons/breeze-dark/apps/48"),
    Path("/usr/share/icons/breeze/apps/48"),
    Path("/usr/share/icons/hicolor/scalable/apps"),
    Path("/usr/share/icons/hicolor/256x256/apps"),
    Path("/usr/share/icons/hicolor/128x128/apps"),
    Path("/usr/share/pixmaps"),
    Path.home() / ".local/share/icons/hicolor/256x256/apps",
    Path.home() / ".local/share/icons/hicolor/scalable/apps",
]


def recolor(svg: str) -> str:
    s = svg
    s = re.sub(r'stroke="#0{3,8}"', 'stroke="#ffffff"', s, flags=re.I)
    s = re.sub(r"stroke='#0{3,8}'", "stroke='#ffffff'", s, flags=re.I)
    s = re.sub(r'fill="#0{3,8}"', 'fill="#ffffff"', s, flags=re.I)
    s = re.sub(r"fill='#0{3,8}'", "fill='#ffffff'", s, flags=re.I)
    s = s.replace("#000000", "#ffffff").replace("#000", "#ffffff")
    return s


def wrap(src: Path) -> str:
    raw = src.read_text(encoding="utf-8", errors="replace")
    m = INNER_RE.search(raw)
    inner = recolor(m.group(1).strip() if m else raw)
    vb = "0 0 192 192"
    vm = VB_RE.search(raw)
    if vm:
        vb = vm.group(1)
    parts = vb.replace(",", " ").split()
    try:
        vw, vh = float(parts[2]), float(parts[3])
    except (IndexError, ValueError):
        vw, vh = 192.0, 192.0
    box = 100.0
    scale = box / max(vw, vh)
    ox = 14 + (box - vw * scale) / 2
    oy = 14 + (box - vh * scale) / 2
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="28" fill="#1a1a1a"/>
  <g transform="translate({ox:.2f},{oy:.2f}) scale({scale:.5f})" fill="none">
    {inner}
  </g>
</svg>
'''


def write_icon(dest_name: str, src: Path) -> None:
    (APPS / f"{dest_name}.svg").write_text(wrap(src), encoding="utf-8")


def load_source(path: Path, size: int = 96) -> np.ndarray | None:
    try:
        if path.suffix.lower() == ".svg":
            png = subprocess.check_output(
                ["rsvg-convert", "-w", str(size), "-h", str(size), str(path)],
                timeout=4,
                stderr=subprocess.DEVNULL,
            )
            im = PILImage.open(io.BytesIO(png)).convert("RGBA")
        else:
            im = PILImage.open(path).convert("RGBA")
            im.thumbnail((size, size), PILImage.Resampling.LANCZOS)
            canvas = PILImage.new("RGBA", (size, size), (0, 0, 0, 0))
            canvas.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
            im = canvas
        return np.array(im)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None


def compose_squircle(
    garr: np.ndarray, fill: tuple[int, int, int, int] = (26, 26, 26, 255)
) -> PILImage.Image:
    glyph = PILImage.fromarray(np.ascontiguousarray(garr), "RGBA")
    canvas = PILImage.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((0, 0, 127, 127), radius=28, fill=fill)
    x = (128 - glyph.width) // 2
    y = (128 - glyph.height) // 2
    canvas.alpha_composite(glyph, (x, y))
    return canvas


def white_glyph(arr: np.ndarray) -> np.ndarray:
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3].astype(np.float32) / 255.0
    opaque = alpha > 0.35
    out = np.zeros_like(arr)
    out[:, :, 0] = 255
    out[:, :, 1] = 255
    out[:, :, 2] = 255
    if int(opaque.sum()) < 8:
        return out
    samples = rgb[opaque]
    median = np.median(samples, axis=0)
    dist = np.linalg.norm(rgb - median, axis=2)
    close = (dist < 32) & opaque
    frac = float(close.sum()) / max(1, int(opaque.sum()))
    lum = 0.2126 * rgb[:, :, 0] + 0.7152 * rgb[:, :, 1] + 0.0722 * rgb[:, :, 2]
    med_lum = float(0.2126 * median[0] + 0.7152 * median[1] + 0.0722 * median[2])
    # Breeze-dark actions/mimes are already white on transparent.
    if med_lum > 180 and frac > 0.45:
        out[:, :, 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
        return out
    if frac > 0.32:
        if med_lum > 140:
            contrast = np.clip((med_lum - lum - 8) / 85, 0, 1)
        else:
            contrast = np.clip((lum - med_lum - 8) / 85, 0, 1)
        chroma = np.clip((dist - 14) / 45, 0, 1)
        strength = np.maximum(contrast, chroma) * alpha
        if float(strength[opaque].mean()) < 0.04:
            strength = alpha
    else:
        strength = alpha
    out[:, :, 3] = (np.clip(strength, 0, 1) * 255).astype(np.uint8)
    return out


def existing_stems() -> set[str]:
    names: set[str] = set()
    for folder in (APPS, RASTER):
        if not folder.is_dir():
            continue
        for p in folder.iterdir():
            if p.suffix.lower() in {".svg", ".png"}:
                names.add(p.stem.lower())
    return names


def collect_sources() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for folder in ICON_DIRS:
        if not folder.is_dir():
            continue
        try:
            entries = list(folder.iterdir())
        except OSError:
            continue
        for path in entries:
            if path.suffix.lower() not in {".svg", ".png", ".xpm"}:
                continue
            key = path.stem.lower()
            prev = out.get(key)
            if prev is None:
                out[key] = path
            elif prev.suffix.lower() != ".svg" and path.suffix.lower() == ".svg":
                out[key] = path
    return out


def fill_from_system() -> int:
    RASTER.mkdir(parents=True, exist_ok=True)
    have = existing_stems()
    sources = collect_sources()
    n = 0
    for key, src in sources.items():
        if key in have:
            continue
        try:
            arr = load_source(src)
            if arr is None:
                continue
            glyph = white_glyph(arr)
            if int(glyph[:, :, 3].max()) < 20:
                continue
            dest = RASTER / f"{src.stem}.png"
            compose_squircle(glyph).save(dest)
        except Exception:
            continue
        have.add(key)
        n += 1
        if n % 400 == 0:
            print(f"  converted {n} …", flush=True)
    return n


def fill_plain(src_dir: Path, dest_dir: Path, size: int) -> int:
    """White glyphs on transparent - sidebar and toolbar (no squircle)."""
    if not src_dir.is_dir():
        return 0
    dest_dir.mkdir(parents=True, exist_ok=True)
    have = {p.stem.lower() for p in dest_dir.glob("*.png")}
    n = 0
    for src in src_dir.iterdir():
        if src.suffix.lower() not in {".svg", ".png"}:
            continue
        if src.stem.lower() in have:
            continue
        arr = load_source(src, size)
        if arr is None:
            continue
        glyph = white_glyph(arr)
        if int(glyph[:, :, 3].max()) < 20:
            continue
        PILImage.fromarray(np.ascontiguousarray(glyph), "RGBA").save(
            dest_dir / f"{src.stem}.png"
        )
        have.add(src.stem.lower())
        n += 1
    return n


def fill_squircles(src_dir: Path, dest_dir: Path, glyph_size: int, skip: set[str]) -> int:
    """White glyphs on dark squircles - Dolphin icon view, like exemple2."""
    if not src_dir.is_dir():
        return 0
    dest_dir.mkdir(parents=True, exist_ok=True)
    have = {p.stem.lower() for p in dest_dir.glob("*.png")} | skip
    n = 0
    for src in src_dir.iterdir():
        if src.suffix.lower() not in {".svg", ".png"}:
            continue
        if src.stem.lower() in have:
            continue
        arr = load_source(src, glyph_size)
        if arr is None:
            continue
        glyph = white_glyph(arr)
        if int(glyph[:, :, 3].max()) < 20:
            continue
        compose_squircle(glyph, fill=(58, 58, 58, 255)).save(dest_dir / f"{src.stem}.png")
        have.add(src.stem.lower())
        n += 1
    return n


def first_icon_dir(*candidates: Path) -> Path:
    for path in candidates:
        if path.is_dir():
            return path
    return candidates[-1]


def write_folder_svgs() -> set[str]:
    """Hand-drawn Nothing folders (outline on squircle) for the grid."""
    dest = DEST / "scalable/places"
    dest.mkdir(parents=True, exist_ok=True)
    plate = '<rect width="128" height="128" rx="28" fill="#3a3a3a"/>'
    folder = (
        '<path fill="none" stroke="#ffffff" stroke-width="5.5" '
        'stroke-linejoin="round" stroke-linecap="round" '
        'd="M34 52h18l7 7h35a8 8 0 0 1 8 8v29a8 8 0 0 1-8 8H34a8 8 0 0 1-8-8V60a8 8 0 0 1 8-8z"/>'
    )
    extras = {
        "folder": "",
        "inode-directory": "",
        "folder-open": (
            '<path fill="none" stroke="#ffffff" stroke-width="4" '
            'stroke-linejoin="round" d="M30 88h68l-8-22H40z"/>'
        ),
        "user-home": (
            '<path fill="none" stroke="#ffffff" stroke-width="4.5" '
            'stroke-linejoin="round" d="M52 86V74l12-9 12 9v12"/>'
        ),
        "user-desktop": (
            '<rect x="48" y="64" width="32" height="22" rx="3" fill="none" '
            'stroke="#ffffff" stroke-width="4"/>'
        ),
        "folder-documents": (
            '<path fill="none" stroke="#ffffff" stroke-width="4" '
            'd="M54 68h20M54 76h16M54 84h12"/>'
        ),
        "folder-download": (
            '<path fill="none" stroke="#ffffff" stroke-width="4.5" '
            'stroke-linecap="round" d="M64 66v18M56 76l8 8 8-8"/>'
        ),
        "folder-pictures": (
            '<circle cx="54" cy="72" r="3" fill="#ffffff"/>'
            '<path fill="none" stroke="#ffffff" stroke-width="4" '
            'stroke-linejoin="round" d="M48 90l10-12 8 8 6-6 8 10"/>'
        ),
        "folder-music": (
            '<path fill="none" stroke="#ffffff" stroke-width="4.5" '
            'stroke-linecap="round" d="M58 86V70l16-4v16"/>'
            '<circle cx="54" cy="86" r="4" fill="#ffffff"/>'
            '<circle cx="70" cy="82" r="4" fill="#ffffff"/>'
        ),
        "folder-videos": (
            '<path fill="#ffffff" d="M56 70l16 10-16 10z"/>'
        ),
        "folder-publicshare": "",
        "folder-remote": "",
        "user-trash": (
            '<path fill="none" stroke="#ffffff" stroke-width="4" '
            'stroke-linejoin="round" d="M50 70h28l-3 18H53zM48 66h32"/>'
        ),
        "drive-harddisk": (
            '<rect x="40" y="58" width="48" height="32" rx="6" fill="none" '
            'stroke="#ffffff" stroke-width="5"/>'
            '<circle cx="72" cy="74" r="4" fill="#ffffff"/>'
        ),
    }
    names: set[str] = set()
    for name, extra in extras.items():
        (dest / f"{name}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" '
            f'viewBox="0 0 128 128">\n  {plate}\n  {folder}\n  {extra}\n</svg>\n',
            encoding="utf-8",
        )
        names.add(name)
    return names


def fill_dolphin_chrome() -> int:
    breeze = Path("/usr/share/icons/breeze-dark")
    for leftover in (
        DEST / "64/places",
        DEST / "64/mimetypes",
        DEST / "22/places",
        DEST / "22/mimetypes",
    ):
        if leftover.is_dir():
            shutil.rmtree(leftover)
    custom = write_folder_svgs()
    n = len(custom)
    jobs = (
        ("actions", breeze / "actions/22", DEST / "22/actions", 22, False),
        ("places-128", breeze / "places/64", DEST / "128/places", 76, True),
        ("mimes-128", breeze / "mimetypes/64", DEST / "128/mimetypes", 76, True),
    )
    for label, src, dest, size, squircles in jobs:
        added = (
            fill_squircles(src, dest, size, custom)
            if squircles
            else fill_plain(src, dest, size)
        )
        print(f"  {label}: +{added}", flush=True)
        n += added
    return n


def apply_aliases() -> None:
    for dest_name, drawable in ALIASES.items():
        src = CACHE / f"{drawable}.svg"
        if src.is_file():
            write_icon(dest_name, src)


def apply_gaps() -> None:
    gaps = ROOT / "theme/icons/Nothing/scalable/apps"
    if not gaps.is_dir():
        return
    always = {
        "endeavouros.svg",
        "endeavouros-icon.svg",
        "distributor-logo-endeavouros.svg",
        "distributor-logo.svg",
        "obs.svg",
        "com.obsproject.studio.svg",
    }
    for src in gaps.glob("*.svg"):
        target = APPS / src.name
        if not target.exists() or src.name in always:
            shutil.copy2(src, target)


def main() -> int:
    if not CACHE.is_dir():
        print(f"lawnicons cache missing: {CACHE}", file=sys.stderr)
        return 1

    APPS.mkdir(parents=True, exist_ok=True)
    RASTER.mkdir(parents=True, exist_ok=True)
    existing = sum(1 for _ in APPS.glob("*.svg"))
    (DEST / "index.theme").write_text(INDEX, encoding="utf-8")
    (DEST / "NOTICE").write_text(
        "Lawnicons glyphs (Apache-2.0) plus converted system app icons.\n"
        "https://github.com/LawnchairLauncher/lawnicons\n",
        encoding="utf-8",
    )

    if existing > 1000 and not FORCE:
        apply_aliases()
        apply_gaps()
        filled = fill_from_system()
        chrome = fill_dolphin_chrome()
        print(f"aliases + {filled} app icons + {chrome} dolphin glyphs → {DEST}")
        return 0

    n = 0
    for src in CACHE.glob("*.svg"):
        write_icon(src.stem, src)
        dashed = src.stem.replace("_", "-")
        if dashed != src.stem:
            write_icon(dashed, src)
        n += 1

    apply_aliases()
    apply_gaps()
    filled = fill_from_system()
    chrome = fill_dolphin_chrome()
    print(f"wrote {n} lawnicons, {filled} apps, {chrome} dolphin glyphs → {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

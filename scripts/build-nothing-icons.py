#!/usr/bin/env python3
"""Build the Nothing icon theme: file manager chrome only.

Folders, file types and toolbar glyphs get the Nothing treatment, a white
silhouette on a dark squircle. Application icons are NOT built here: the
theme inherits Qogir-Dark for those, so an app gets its normal icon and
nothing has to be generated per application.

Usage:
  scripts/build-nothing-icons.py [DEST_DIR] [--force|--recolor]
"""
from __future__ import annotations

import io
import shutil
import subprocess
import sys
from pathlib import Path

from multiprocessing import Pool, cpu_count

import numpy as np
from PIL import Image as PILImage
from PIL import ImageDraw

raw_args = sys.argv[1:]
FORCE = "--force" in raw_args
# Recolouring reuses the glyph masters from the previous build instead of
# rasterising every source icon again. Rasterising is the whole cost of a
# build, so this is the difference between seconds and a minute.
RECOLOR = "--recolor" in raw_args
# What sits behind the glyph. "none" is the plain silhouette. "circle" is
# what Nothing OS draws: their launcher's icon_pack_themed_icon_nothing
# vector is four quarter-arcs of radius 24 on a 48 box, a plain disc.
NO_PLATE = "--no-plate" in raw_args
CIRCLE = "--circle" in raw_args


def take_opt(name: str, default: str) -> str:
    """--name VALUE or --name=VALUE, removed from the positional list."""
    for i, a in enumerate(raw_args):
        if a == name and i + 1 < len(raw_args):
            v = raw_args[i + 1]
            del raw_args[i:i + 2]
            return v
        if a.startswith(name + "="):
            v = a.split("=", 1)[1]
            del raw_args[i]
            return v
    return default


GLYPH = take_opt("--glyph", "#ffffff")
PLATE = take_opt("--plate", "#1a1a1a")
# The lighter plate used for folders and file types, so they stay a step
# above the shell's own background as they did before.
PLATE_ALT = take_opt("--plate-alt", "")


def hex_rgba(h: str) -> tuple[int, int, int, int]:
    h = h.strip().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16),
            int(h[6:8], 16) if len(h) >= 8 else 255)


def lift(h: str, amount: int = 32) -> str:
    """A slightly lighter plate, derived rather than hardcoded."""
    r, g, b, _ = hex_rgba(h)
    return "#%02x%02x%02x" % tuple(min(255, c + amount) for c in (r, g, b))


if not PLATE_ALT:
    PLATE_ALT = lift(PLATE)

args = [a for a in raw_args if not a.startswith("--")]
FINAL = Path(args[0]) if args else Path.home() / ".local/share/icons/Nothing"
# Writing in place left the theme half-finished while it built, and Dolphin
# drew blanks. Build beside it, swap at the end.
STAGE = FORCE or RECOLOR
DEST = FINAL.with_name(FINAL.name + ".building") if STAGE else FINAL
# Neutral masters: the silhouette alone, white on transparent, mirroring the
# layout of the icons built from them. Keeping them means a later change of
# colour only has to repaint, never to rasterise the sources again.
GLYPHS = DEST / "glyphs"
MASTER_SRC = FINAL / "glyphs"

# Applications are deliberately absent: Inherits hands them to Qogir-Dark.
INDEX = """[Icon Theme]
Name=Nothing
Comment=Nothing OS - white glyphs on dark squircles (file manager chrome)
Inherits=Qogir-Dark,breeze-dark,hicolor
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

Directories=scalable/places,128/places,128/mimetypes,22/actions

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
    garr: np.ndarray, fill: tuple[int, int, int, int] | None = None
) -> PILImage.Image:
    if fill is None:
        fill = hex_rgba(PLATE)
    glyph = PILImage.fromarray(np.ascontiguousarray(garr), "RGBA")
    canvas = PILImage.new("RGBA", (128, 128), (0, 0, 0, 0))
    if not NO_PLATE:
        draw = ImageDraw.Draw(canvas)
        if CIRCLE:
            draw.ellipse((0, 0, 127, 127), fill=fill)
        else:
            draw.rounded_rectangle((0, 0, 127, 127), radius=28, fill=fill)
    x = (128 - glyph.width) // 2
    y = (128 - glyph.height) // 2
    canvas.alpha_composite(glyph, (x, y))
    return canvas


# Which plate each built directory sits on, so a recolour recomposes exactly
# what the original build produced. Anything absent is a plain glyph on
# transparent, the toolbar style with no plate at all.
PLATED = {"128/places": "alt", "128/mimetypes": "alt"}


def master_for(dest_file: Path) -> Path:
    return GLYPHS / dest_file.relative_to(DEST)


def save_master(dest_file: Path, glyph: np.ndarray) -> None:
    """Keep the silhouette that produced this icon. Alpha carries the shape,
    so the colour channels are neutralised and a recolour just repaints."""
    out = glyph.copy()
    out[:, :, 0] = 255
    out[:, :, 1] = 255
    out[:, :, 2] = 255
    m = master_for(dest_file)
    m.parent.mkdir(parents=True, exist_ok=True)
    PILImage.fromarray(np.ascontiguousarray(out), "RGBA").save(m)


def white_glyph(arr: np.ndarray) -> np.ndarray:
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3].astype(np.float32) / 255.0
    opaque = alpha > 0.35
    gr, gg, gb, _ = hex_rgba(GLYPH)
    out = np.zeros_like(arr)
    out[:, :, 0] = gr
    out[:, :, 1] = gg
    out[:, :, 2] = gb
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


def fill_plain(src_dir: Path, dest_dir: Path, size: int) -> int:
    """White glyphs on transparent - sidebar and toolbar (no squircle)."""
    if not src_dir.is_dir():
        return 0
    dest_dir.mkdir(parents=True, exist_ok=True)
    have = set() if FORCE else {p.stem.lower() for p in dest_dir.glob("*.png")}
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
        dest = dest_dir / f"{src.stem}.png"
        PILImage.fromarray(np.ascontiguousarray(glyph), "RGBA").save(dest)
        save_master(dest, glyph)
        have.add(src.stem.lower())
        n += 1
    return n


def fill_squircles(src_dir: Path, dest_dir: Path, glyph_size: int, skip: set[str]) -> int:
    """White glyphs on dark squircles - the Dolphin icon view."""
    if not src_dir.is_dir():
        return 0
    dest_dir.mkdir(parents=True, exist_ok=True)
    have = skip if FORCE else ({p.stem.lower() for p in dest_dir.glob("*.png")} | skip)
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
        dest = dest_dir / f"{src.stem}.png"
        compose_squircle(glyph, fill=hex_rgba(PLATE_ALT)).save(dest)
        save_master(dest, glyph)
        have.add(src.stem.lower())
        n += 1
    return n


def write_folder_svgs() -> set[str]:
    """Hand-drawn Nothing folders (outline on squircle) for the grid."""
    dest = DEST / "scalable/places"
    dest.mkdir(parents=True, exist_ok=True)
    if NO_PLATE:
        plate = ""
    elif CIRCLE:
        plate = f'<circle cx="64" cy="64" r="64" fill="{PLATE_ALT}"/>'
    else:
        plate = f'<rect width="128" height="128" rx="28" fill="{PLATE_ALT}"/>'
    folder = (
        f'<path fill="none" stroke="{GLYPH}" stroke-width="5.5" '
        'stroke-linejoin="round" stroke-linecap="round" '
        'd="M34 52h18l7 7h35a8 8 0 0 1 8 8v29a8 8 0 0 1-8 8H34a8 8 0 0 1-8-8V60a8 8 0 0 1 8-8z"/>'
    )
    extras = {
        "folder": "",
        "inode-directory": "",
        "folder-open": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4" '
            'stroke-linejoin="round" d="M30 88h68l-8-22H40z"/>'
        ),
        "user-home": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4.5" '
            'stroke-linejoin="round" d="M52 86V74l12-9 12 9v12"/>'
        ),
        "user-desktop": (
            '<rect x="48" y="64" width="32" height="22" rx="3" fill="none" '
            f'stroke="{GLYPH}" stroke-width="4"/>'
        ),
        "folder-documents": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4" '
            'd="M54 68h20M54 76h16M54 84h12"/>'
        ),
        "folder-download": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4.5" '
            'stroke-linecap="round" d="M64 66v18M56 76l8 8 8-8"/>'
        ),
        "folder-pictures": (
            f'<circle cx="54" cy="72" r="3" fill="{GLYPH}"/>'
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4" '
            'stroke-linejoin="round" d="M48 90l10-12 8 8 6-6 8 10"/>'
        ),
        "folder-music": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4.5" '
            'stroke-linecap="round" d="M58 86V70l16-4v16"/>'
            f'<circle cx="54" cy="86" r="4" fill="{GLYPH}"/>'
            f'<circle cx="70" cy="82" r="4" fill="{GLYPH}"/>'
        ),
        "folder-videos": (
            f'<path fill="{GLYPH}" d="M56 70l16 10-16 10z"/>'
        ),
        "folder-publicshare": "",
        "folder-remote": "",
        "user-trash": (
            f'<path fill="none" stroke="{GLYPH}" stroke-width="4" '
            'stroke-linejoin="round" d="M50 70h28l-3 18H53zM48 66h32"/>'
        ),
        "drive-harddisk": (
            '<rect x="40" y="58" width="48" height="32" rx="6" fill="none" '
            f'stroke="{GLYPH}" stroke-width="5"/>'
            f'<circle cx="72" cy="74" r="4" fill="{GLYPH}"/>'
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


def repaint(job: tuple[str, str]) -> bool:
    """Repaint one master into a finished icon. Runs in a worker process."""
    rel, kind = job
    try:
        im = PILImage.open(MASTER_SRC / rel).convert("RGBA")
        arr = np.array(im)
        gr, gg, gb, _ = hex_rgba(GLYPH)
        arr[:, :, 0] = gr
        arr[:, :, 1] = gg
        arr[:, :, 2] = gb
        glyph = PILImage.fromarray(np.ascontiguousarray(arr), "RGBA")
        dest = DEST / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if kind == "":
            glyph.save(dest)
        else:
            canvas = PILImage.new("RGBA", (128, 128), (0, 0, 0, 0))
            if not NO_PLATE:
                fill = hex_rgba(PLATE if kind == "plate" else PLATE_ALT)
                d = ImageDraw.Draw(canvas)
                if CIRCLE:
                    d.ellipse((0, 0, 127, 127), fill=fill)
                else:
                    d.rounded_rectangle((0, 0, 127, 127), radius=28, fill=fill)
            canvas.alpha_composite(
                glyph, ((128 - glyph.width) // 2, (128 - glyph.height) // 2)
            )
            canvas.save(dest)
    except Exception:
        return False
    return True


def recolor_from_masters() -> int:
    """Rebuild every rasterised icon from the stored silhouettes.

    This is the same output as a full build, without opening a single source
    icon again: no SVG rasterising and no colour analysis, only a repaint.
    """
    jobs = []
    for m in MASTER_SRC.rglob("*.png"):
        rel = m.relative_to(MASTER_SRC)
        jobs.append((str(rel), PLATED.get(str(rel.parent), "")))
    if not jobs:
        return 0
    with Pool(min(cpu_count(), 16)) as pool:
        done = sum(1 for ok in pool.imap_unordered(repaint, jobs, 64) if ok)
    # Carry the masters forward so the next recolour has them too.
    shutil.copytree(MASTER_SRC, GLYPHS, dirs_exist_ok=True)
    return done


def stamp_palette() -> None:
    """Record the pair the icons are actually painted with.

    Written only once the painting is done: stamped up front, it would claim
    colours the files do not have yet, and an interrupted run would leave the
    next one thinking there was nothing to repaint.
    """
    if NO_PLATE:
        plate = "no-plate"
    else:
        plate = f"{'circle' if CIRCLE else 'squircle'} {PLATE} {PLATE_ALT}"
    (DEST / "palette").write_text(f"{GLYPH} {plate}\n", encoding="utf-8")


def swap_in() -> None:
    """Put the staged build in place of the live theme in one rename."""
    if DEST == FINAL:
        return
    old = FINAL.with_name(FINAL.name + ".old")
    shutil.rmtree(old, ignore_errors=True)
    if FINAL.exists():
        FINAL.rename(old)
    DEST.rename(FINAL)
    shutil.rmtree(old, ignore_errors=True)


def main() -> int:
    # A staging directory left behind by an interrupted run would otherwise
    # be mistaken for finished work and skip the rebuild.
    if DEST != FINAL:
        shutil.rmtree(DEST, ignore_errors=True)

    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "index.theme").write_text(INDEX, encoding="utf-8")

    if RECOLOR and MASTER_SRC.is_dir():
        write_folder_svgs()
        painted = recolor_from_masters()
        stamp_palette()
        swap_in()
        print(f"recoloured {painted} icons → {FINAL}")
        return 0

    chrome = fill_dolphin_chrome()
    stamp_palette()
    swap_in()
    print(f"wrote {chrome} file manager glyphs → {FINAL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Intégration au bureau Nothing OS (dotfiles 0xbbuddha, MIT).

Triat partage la palette de ces dotfiles. Quand ils sont présents, l'app lit
leur configuration pour s'accorder au reste du bureau — accent, police —
au lieu d'imposer ses propres valeurs.

Tout est facultatif : sans les dotfiles, les valeurs de DESIGN.md
s'appliquent telles quelles.
"""

from __future__ import annotations

import json
import logging
import os
import re
import shutil
import subprocess
from pathlib import Path

log = logging.getLogger(__name__)

# Chemins posés par le script d'installation des dotfiles.
NOTHING_CONFIG = Path.home() / ".config" / "nothing" / "config.json"
HYPR_CUSTOM = Path.home() / ".config" / "hypr" / "custom.lua"
QUICKSHELL_DIR = Path.home() / ".config" / "quickshell" / "nothing"

# Accent de repli : le rouge Nothing de DESIGN.md §2.
DEFAULT_ACCENT = "#d71921"
_HEX = re.compile(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")

# Clés d'accent rencontrées selon les versions des dotfiles.
_ACCENT_KEYS = ("accent", "accentColor", "colorAccent", "themeAccent")


def dotfiles_present() -> bool:
    """Vrai si le bureau Nothing OS est installé."""
    return NOTHING_CONFIG.is_file() or QUICKSHELL_DIR.is_dir()


def read_desktop_config() -> dict:
    """Configuration des dotfiles, ou dictionnaire vide."""
    try:
        raw = NOTHING_CONFIG.read_text(encoding="utf-8")
    except OSError:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        log.info("Configuration du bureau illisible : %s", exc)
        return {}
    return data if isinstance(data, dict) else {}


def normalize_hex(value) -> str | None:
    """Valide une couleur hexadécimale et la développe en 6 chiffres."""
    if not isinstance(value, str):
        return None
    value = value.strip()
    if not _HEX.match(value):
        return None
    if len(value) == 4:      # #abc -> #aabbcc
        value = "#" + "".join(c * 2 for c in value[1:])
    return value.lower()


def desktop_accent() -> str | None:
    """Accent du bureau, ou None s'il n'est pas lisible."""
    config = read_desktop_config()
    for key in _ACCENT_KEYS:
        accent = normalize_hex(config.get(key))
        if accent:
            return accent
    return None


def display_font() -> str:
    """Police d'affichage à privilégier.

    GTK.md §2 : si Ndot — la police des dotfiles — est installée, elle
    remplace Doto. Sinon on garde Doto, embarquée avec l'application.
    """
    try:
        import gi

        gi.require_version("PangoCairo", "1.0")
        from gi.repository import PangoCairo

        families = {f.get_name().lower()
                    for f in PangoCairo.FontMap.get_default().list_families()}
    except Exception:
        return "Doto"
    for candidate in ("ndot 57", "ndot-57", "ndot"):
        if candidate in families:
            # Renvoie le nom tel que Pango le connaît.
            for name in families:
                if name == candidate:
                    return candidate.title()
    return "Doto"


def accent_css(accent: str) -> str:
    """Feuille minimale qui réécrit l'accent, à charger en priorité haute.

    GTK.md §2 décrit exactement ce mécanisme : un second CssProvider plutôt
    qu'une réécriture de la feuille principale.
    """
    return (":root {\n"
            f"  --triat-accent: {accent};\n"
            f"  --accent-bg-color: {accent};\n"
            "}\n")


def describe() -> dict:
    """Résumé de l'intégration, pour le diagnostic."""
    accent = desktop_accent()
    return {
        "dotfiles": dotfiles_present(),
        "config": str(NOTHING_CONFIG) if NOTHING_CONFIG.is_file() else None,
        "accent": accent,
        "quickshell": QUICKSHELL_DIR.is_dir(),
        "hypr_custom": HYPR_CUSTOM.is_file(),
        "display_font": display_font(),
    }


def focus_under_hyprland(app_id: str) -> bool:
    """Donne le focus à la fenêtre de `app_id` sous Hyprland.

    Une application réactivée (lanceur, raccourci, barre) appelle
    `present()`, mais Hyprland ne cède le focus qu'avec un jeton
    d'activation, que les lanceurs ne transmettent pas toujours : la
    fenêtre restait sur son bureau. On le demande donc au compositeur.
    Syntaxe Lua (Hyprland ≥ 0.56), puis classique en repli.
    """
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return False
    hyprctl = shutil.which("hyprctl")
    if hyprctl is None:
        return False
    pattern = "^(" + re.escape(app_id) + ")$"
    lua_pattern = pattern.replace("\\", "\\\\")
    for command in (f'hl.dsp.focus({{ window = "class:{lua_pattern}" }})',
                    f"focuswindow class:{pattern}"):
        try:
            result = subprocess.run([hyprctl, "dispatch", command],
                                    capture_output=True, text=True, timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            return False
        if result.stdout.strip() == "ok":
            return True
    return False

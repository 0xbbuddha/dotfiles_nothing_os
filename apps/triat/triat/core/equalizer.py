"""Égaliseur 10 bandes, traduit en filtres audio mpv.

Chaque bande est un filtre `equalizer` de FFmpeg (crête d'une octave de
large). Une pré-atténuation égale au gain le plus fort évite l'écrêtage :
monter les basses de 6 dB sans elle sature dès le premier kick.
"""

from __future__ import annotations

import math
from collections.abc import Sequence

# Fréquences centrales en Hz, une par octave : la grille ISO habituelle.
BANDS: tuple[int, ...] = (31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)

GAIN_MIN = -12.0
GAIN_MAX = 12.0

FLAT: tuple[float, ...] = (0.0,) * len(BANDS)

# (identifiant, libellé, gains) — l'ordre est celui du menu.
PRESETS: tuple[tuple[str, str, tuple[float, ...]], ...] = (
    ("flat", "Plat", FLAT),
    ("bass", "Basses", (6, 5, 4, 2, 0, 0, 0, 0, 0, 0)),
    ("treble", "Aigus", (0, 0, 0, 0, 0, 1, 2, 4, 5, 6)),
    ("vocal", "Voix", (-2, -2, -1, 0, 2, 4, 4, 2, 0, -1)),
    ("rock", "Rock", (4, 3, 2, 0, -1, -1, 1, 3, 4, 4)),
    ("electronic", "Électro", (5, 4, 1, 0, -2, 1, 0, 1, 4, 5)),
    ("acoustic", "Acoustique", (3, 3, 2, 1, 1, 1, 2, 3, 2, 1)),
    ("loudness", "Faible volume", (6, 4, 2, 0, 0, 0, 0, 2, 4, 5)),
)

CUSTOM = "custom"


def clamp_gains(gains: Sequence[float] | None) -> tuple[float, ...]:
    """Gains valides : dix nombres dans [-12, 12]. Tout le reste → plat.

    Les réglages viennent d'un JSON éditable à la main ; une valeur
    aberrante ne doit pas atteindre la chaîne de filtres de mpv.
    """
    if not isinstance(gains, (list, tuple)) or len(gains) != len(BANDS):
        return FLAT
    out = []
    for gain in gains:
        if isinstance(gain, bool) or not isinstance(gain, (int, float)):
            return FLAT
        if math.isnan(gain):
            return FLAT
        out.append(round(max(GAIN_MIN, min(GAIN_MAX, float(gain))), 1))
    return tuple(out)


def preset_gains(preset_id: str) -> tuple[float, ...] | None:
    for pid, _label, gains in PRESETS:
        if pid == preset_id:
            return tuple(float(g) for g in gains)
    return None


def match_preset(gains: Sequence[float]) -> str:
    """Identifiant du préréglage égal à ces gains, sinon « custom »."""
    gains = clamp_gains(gains)
    for pid, _label, preset in PRESETS:
        if gains == tuple(float(g) for g in preset):
            return pid
    return CUSTOM


def build_filter(gains: Sequence[float]) -> str:
    """Graphe lavfi pour mpv, ou chaîne vide si l'égaliseur est neutre."""
    gains = clamp_gains(gains)
    if all(g == 0 for g in gains):
        return ""
    stages = []
    headroom = max(gains)
    if headroom > 0:
        stages.append(f"volume={-headroom:g}dB")
    for freq, gain in zip(BANDS, gains, strict=True):
        if gain:
            stages.append(f"equalizer=f={freq}:t=o:w=1:g={gain:g}")
    return "lavfi=[" + ",".join(stages) + "]"

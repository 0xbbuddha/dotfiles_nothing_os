"""Glyph — matrice de points façon Nothing.

Trois sources possibles pour l'intensité de chaque point :
- un motif génératif tiré d'une graine (vignettes de mixes) ;
- la trame d'une pochette, réduite à une grille de luminances (Immersion) ;
- par-dessus, un spectre audio qui fait gonfler les colonnes.

Tous les points existent toujours : éteints, ils restent visibles en gris,
comme les LED d'une matrice. Le rendu groupe les points par niveau
d'intensité et dessine un seul chemin par niveau : quelques appels GSK
au lieu d'un par point, ce qui tient 30 images/s même à 64×64.
"""

from __future__ import annotations

import logging
import math
import random
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gsk", "4.0")
gi.require_version("Graphene", "1.0")
gi.require_version("GdkPixbuf", "2.0")

from gi.repository import GdkPixbuf, GLib, Graphene, Gsk, Gtk

from ...core import artwork
from .dot_progress import rgba

log = logging.getLogger(__name__)

LEVELS = 8           # paliers d'intensité dessinés
OFF_COLOUR = "#262626"
MOTIFS = ("orbite", "onde", "soleil", "trame", "eclat", "maree")


def motif_field(seed: int, grid: int) -> list[float]:
    """Champ d'intensités 0-1 (ligne par ligne) tiré d'une graine."""
    rng = random.Random(seed)
    motif = MOTIFS[seed % len(MOTIFS)]
    cx = rng.uniform(0.25, 0.75)
    cy = rng.uniform(0.25, 0.75)
    freq = rng.uniform(2.2, 4.2)
    phase = rng.uniform(0, math.tau)
    out: list[float] = []
    for row in range(grid):
        for col in range(grid):
            x = (col + 0.5) / grid
            y = (row + 0.5) / grid
            d = math.hypot(x - cx, y - cy)
            if motif == "orbite":
                v = 1.0 - abs(math.sin(d * freq * math.pi + phase))
                v = v ** 3
            elif motif == "onde":
                v = 0.5 + 0.5 * math.sin(x * freq * math.tau
                                         + math.sin(y * 3 + phase) * 1.6)
                v = v ** 2
            elif motif == "soleil":
                v = max(0.0, 1.0 - d / (0.28 + 0.1 * freq / 4))
            elif motif == "trame":
                v = (1.0 - y) ** 1.4 if (col + row) % 2 == 0 else 0.0
            elif motif == "eclat":
                angle = math.atan2(y - cy, x - cx)
                v = (0.5 + 0.5 * math.cos(angle * round(freq * 2) + phase)) \
                    * max(0.0, 1.0 - d * 1.4)
            else:  # marée
                v = 1.0 if y > 0.55 + 0.18 * math.sin(x * freq * 2 + phase) \
                    else 0.0
            out.append(max(0.0, min(1.0, v)))
    return out


def luminance_field(path: str, grid: int) -> list[float] | None:
    """Pochette réduite à `grid`×`grid` luminances, recadrée au carré."""
    try:
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
    except GLib.Error as exc:
        log.debug("Pochette illisible : %s", exc)
        return None
    side = min(pixbuf.get_width(), pixbuf.get_height())
    square = pixbuf.new_subpixbuf((pixbuf.get_width() - side) // 2,
                                  (pixbuf.get_height() - side) // 2,
                                  side, side)
    small = square.scale_simple(grid, grid, GdkPixbuf.InterpType.BILINEAR)
    data = small.get_pixels()
    stride = small.get_rowstride()
    channels = small.get_n_channels()
    values = []
    for row in range(grid):
        for col in range(grid):
            i = row * stride + col * channels
            r, g, b = data[i], data[i + 1], data[i + 2]
            values.append((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255)
    # Étirement du contraste : une pochette sombre resterait sinon éteinte.
    low, high = min(values), max(values)
    span = (high - low) or 1.0
    return [((v - low) / span) ** 1.25 for v in values]


class GlyphArt(Gtk.Widget):
    __gtype_name__ = "TriatGlyphArt"

    def __init__(self, grid: int = 16, size: int = 120,
                 radius: float = 24.0, square: bool = True) -> None:
        super().__init__()
        self.add_css_class("triat-glyph")
        self.grid = grid
        self._size = size
        self._radius = radius
        self._square = square
        self._field: list[float] = [0.0] * (grid * grid)
        self._levels: list[float] = []
        self._token = 0
        self._base_node = None
        self._column_nodes: dict = {}
        self._signature = None
        self.set_overflow(Gtk.Overflow.HIDDEN)

    # ---- Sources ---------------------------------------------------------

    def set_seed(self, seed: int) -> None:
        self._shown = None
        self._token += 1
        self._field = motif_field(seed, self.grid)
        self.queue_draw()

    def set_track(self, ref, fallback_seed: int = 0) -> None:
        """Trame de la pochette ; motif tiré de l'ID en attendant."""
        video_id = getattr(ref, "video_id", "") if ref else ""
        url = getattr(ref, "thumbnail", None) if ref else None
        # Même piste : la trame est déjà là (l'accueil la redemandait à
        # chaque lecture/pause, avec un thread et un calcul de luminance).
        if (video_id, url) == getattr(self, "_shown", None):
            return
        self._shown = (video_id, url)
        self._token += 1
        token = self._token
        self._field = motif_field(
            fallback_seed or sum(map(ord, video_id)), self.grid)
        self.queue_draw()
        if url:
            threading.Thread(target=self._load, args=(url, token),
                             daemon=True).start()

    def set_levels(self, levels: list[float]) -> None:
        """Spectre 0-1 par bande ; liste vide pour l'arrêter."""
        self._levels = levels
        self.queue_draw()

    def _load(self, url: str, token: int) -> None:
        path = artwork.fetch(url)
        field = luminance_field(str(path), self.grid) if path else None
        if field is not None:
            GLib.idle_add(self._apply, field, token)

    def _apply(self, field: list[float], token: int) -> bool:
        if token == self._token:
            self._field = field
            self.queue_draw()
        return GLib.SOURCE_REMOVE

    # ---- Rendu -----------------------------------------------------------
    #
    # Le rendu naïf reconstruisait 2 304 cercles en Python à chaque image :
    # 48 % d'un cœur à 30 images/s. On découpe donc en nœuds GSK en cache :
    # - le fond (la trame, points éteints compris), recalculé seulement si
    #   la taille, la source ou la couleur changent ;
    # - pour chaque colonne et chaque hauteur de barre, le nœud des points
    #   « allumés » par le spectre, construit à la première demande.
    # Une image ne coûte plus qu'une cinquantaine d'appels.

    def _invalidate(self) -> None:
        self._base_node = None
        self._column_nodes = {}

    def _geometry(self, width: int, height: int):
        side = min(width, height) if self._square else None
        w = side or width
        h = side or height
        ox, oy = (width - w) / 2, (height - h) / 2
        step = min(w, h) / self.grid
        gx = ox + (w - step * self.grid) / 2
        gy = oy + (h - step * self.grid) / 2
        return ox, oy, w, h, step, gx, gy

    def _dots_node(self, cells, geometry, colour):
        """Nœud GSK des points `cells` = [(index, intensité)]."""
        step, gx, gy = geometry[4:]
        max_r, min_r = step * 0.42, step * 0.14
        builders: dict[int, Gsk.PathBuilder] = {}
        for index, value in cells:
            lvl = int(round(value * LEVELS))
            row, col = divmod(index, self.grid)
            builder = builders.get(lvl)
            if builder is None:
                builder = builders[lvl] = Gsk.PathBuilder.new()
            builder.add_circle(
                Graphene.Point().init(gx + (col + 0.5) * step,
                                      gy + (row + 0.5) * step),
                min_r + (max_r - min_r) * lvl / LEVELS)
        snapshot = Gtk.Snapshot()
        for lvl, builder in sorted(builders.items()):
            if lvl == 0:
                paint = rgba(OFF_COLOUR)
            else:
                paint = colour.copy()
                paint.alpha = 0.35 + 0.65 * lvl / LEVELS
            snapshot.append_fill(builder.to_path(), Gsk.FillRule.WINDING, paint)
        return snapshot.to_node()

    def _bake(self, node):
        """Aplatit un nœud en texture GPU : le moteur de rendu GTK
        re-rastérise les chemins à chaque image, pas une texture."""
        if node is None:
            return None
        native = self.get_native()
        renderer = native.get_renderer() if native is not None else None
        if renderer is None:
            return node
        bounds = node.get_bounds()
        if bounds.get_width() <= 0 or bounds.get_height() <= 0:
            return node
        scale = max(1, self.get_scale_factor())
        source, area = node, bounds
        if scale > 1:
            # Rendu à la densité de l'écran, sinon flou en HiDPI.
            scaled = Gtk.Snapshot()
            scaled.scale(scale, scale)
            scaled.append_node(node)
            source = scaled.to_node()
            area = source.get_bounds()
        try:
            texture = renderer.render_texture(source, area)
        except Exception as exc:
            log.debug("Aplatissement impossible : %s", exc)
            return node
        return Gsk.TextureNode.new(texture, bounds)

    def _column_node(self, col: int, lit: int, geometry, colour):
        key = (col, lit)
        if key not in self._column_nodes:
            grid = self.grid
            cells = [(row * grid + col,
                      min(1.0, self._field[row * grid + col] * 0.55 + 0.55))
                     for row in range(grid - lit, grid)]
            self._column_nodes[key] = self._bake(
                self._dots_node(cells, geometry, colour))
        return self._column_nodes[key]

    def do_snapshot(self, snapshot: Gtk.Snapshot) -> None:
        width, height = self.get_width(), self.get_height()
        if width <= 0 or height <= 0:
            return
        colour = self.get_color()
        signature = (width, height, colour.to_string(), id(self._field))
        if signature != self._signature:
            self._signature = signature
            self._invalidate()
        geometry = self._geometry(width, height)
        ox, oy, w, h = geometry[:4]

        if self._radius:
            rect = Graphene.Rect().init(ox, oy, w, h)
            clip = Gsk.RoundedRect()
            clip.init_from_rect(rect, self._radius)
            snapshot.push_rounded_clip(clip)

        if self._base_node is None:
            self._base_node = self._bake(self._dots_node(
                list(enumerate(self._field)), geometry, colour))
        if self._base_node is not None:
            snapshot.append_node(self._base_node)

        if self._levels:
            grid = self.grid
            bands = len(self._levels)
            for col in range(grid):
                level = self._levels[min(bands - 1, col * bands // grid)]
                lit = min(grid, int(level * grid + 0.5))
                if lit > 0:
                    node = self._column_node(col, lit, geometry, colour)
                    if node is not None:
                        snapshot.append_node(node)

        if self._radius:
            snapshot.pop()

    def do_measure(self, orientation, _for_size):
        return (min(self._size, 48), self._size, -1, -1)

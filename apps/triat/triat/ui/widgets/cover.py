"""Cover — pochette réelle, ou motif de points à défaut.

DESIGN.md §5 : « Pochette absente : motif de points généré à partir du hash
de l'ID (disque, anneau, bandes, demi, coin, diagonale). » Le motif est donc
déterministe — une piste donnée garde toujours la même pochette de repli.

Le téléchargement ET le décodage se font dans un petit pool de threads,
à la taille affichée ; les textures sont gardées en mémoire (LRU) et
partagées entre toutes les pochettes. `do_snapshot` ne fait jamais
d'entrée-sortie ni de calcul : le motif de repli est un nœud de rendu
construit une fois par motif et par taille.
"""

from __future__ import annotations

import hashlib
import logging
import math
import threading
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gsk", "4.0")
gi.require_version("Graphene", "1.0")
gi.require_version("GdkPixbuf", "2.0")

from gi.repository import Gdk, GdkPixbuf, GLib, Graphene, Gsk, Gtk

from ...core import artwork
from .dot_progress import rgba

log = logging.getLogger(__name__)

DOT_COLOUR = "#f1f1f1"
BACKGROUND = "#111111"
PATTERNS = ("disque", "anneau", "bandes", "demi", "coin", "diagonale")
GRID = 11          # points par côté


def pattern_for(video_id: str) -> str:
    """Motif déterminé par l'identifiant : stable d'une session à l'autre."""
    if not video_id:
        return PATTERNS[0]
    digest = hashlib.sha256(video_id.encode("utf-8")).digest()
    return PATTERNS[digest[0] % len(PATTERNS)]


def pattern_points(name: str, grid: int = GRID) -> list[tuple[float, float, float]]:
    """Points allumés d'un motif, en coordonnées relatives (0-1) + intensité.

    Calculé une fois par piste, jamais pendant le rendu.
    """
    points: list[tuple[float, float, float]] = []
    centre = (grid - 1) / 2
    for row in range(grid):
        for col in range(grid):
            # Coordonnées centrées, normalisées entre -1 et 1.
            dx = (col - centre) / centre
            dy = (row - centre) / centre
            distance = math.hypot(dx, dy)
            weight = 0.0

            if name == "disque":
                weight = 1.0 if distance <= 0.82 else 0.0
            elif name == "anneau":
                weight = 1.0 if 0.45 <= distance <= 0.85 else 0.0
            elif name == "bandes":
                weight = 1.0 if row % 3 != 2 else 0.0
            elif name == "demi":
                weight = 1.0 if dy <= 0.05 else 0.0
            elif name == "coin":
                weight = 1.0 if (dx + dy) <= -0.1 else 0.0
            elif name == "diagonale":
                weight = 1.0 if abs(dx - dy) <= 0.45 else 0.0

            if weight > 0 and distance <= 1.05:
                # Les points s'estompent vers le bord : le motif respire.
                fade = max(0.35, 1.0 - 0.45 * distance)
                points.append(((col + 0.5) / grid, (row + 0.5) / grid, fade))
    return points


class _TextureCache:
    """Textures de pochettes, réduites à la taille affichée, partagées.

    Avant : un thread par ligne affichée, et un JPEG 480×360 décodé dans le
    fil de l'interface à chaque réaffichage — d'où les saccades au
    défilement. Maintenant : 4 threads, décodage réduit hors du fil GTK,
    un seul chargement par (image, taille) même demandée dix fois.
    """

    LIMIT = 600

    def __init__(self) -> None:
        self._textures: OrderedDict = OrderedDict()
        self._waiting: dict = {}
        self._pool = ThreadPoolExecutor(max_workers=4,
                                        thread_name_prefix="pochettes")

    def get(self, url: str, pixels: int):
        key = (url, pixels)
        texture = self._textures.get(key)
        if texture is not None:
            self._textures.move_to_end(key)
        return texture

    def request(self, url: str, pixels: int, callback) -> None:
        key = (url, pixels)
        if key in self._waiting:
            self._waiting[key].append(callback)
            return
        self._waiting[key] = [callback]
        self._pool.submit(self._load, key)

    def _load(self, key) -> None:
        url, pixels = key
        pixbuf = None
        path = artwork.fetch(url)
        if path is not None:
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    str(path), pixels, pixels, True)
            except GLib.Error as exc:
                log.debug("Pochette illisible : %s", exc)
        GLib.idle_add(self._deliver, key, pixbuf)

    def _deliver(self, key, pixbuf) -> bool:
        texture = Gdk.Texture.new_for_pixbuf(pixbuf) if pixbuf is not None else None
        if texture is not None:
            self._textures[key] = texture
            while len(self._textures) > self.LIMIT:
                self._textures.popitem(last=False)
        for callback in self._waiting.pop(key, []):
            callback(texture)
        return GLib.SOURCE_REMOVE


TEXTURES = _TextureCache()
_PLACEHOLDERS: dict = {}


def _placeholder_node(pattern: str, side: float, radius: float):
    """Nœud de rendu du motif de repli, construit une seule fois."""
    key = (pattern, round(side), round(radius))
    node = _PLACEHOLDERS.get(key)
    if node is None:
        snapshot = Gtk.Snapshot()
        rect = Graphene.Rect().init(0, 0, side, side)
        snapshot.append_color(rgba(BACKGROUND), rect)
        dot = side / GRID * 0.3
        for rel_x, rel_y, fade in pattern_points(pattern):
            x, y = rel_x * side, rel_y * side
            dot_rect = Graphene.Rect().init(x - dot, y - dot, dot * 2, dot * 2)
            clip = Gsk.RoundedRect()
            clip.init_from_rect(dot_rect, dot)
            snapshot.push_rounded_clip(clip)
            snapshot.append_color(rgba(DOT_COLOUR, fade * 0.9), dot_rect)
            snapshot.pop()
        node = snapshot.to_node()
        _PLACEHOLDERS[key] = node
    return node


class Cover(Gtk.Widget):
    """Pochette carrée. Affiche l'image réelle dès qu'elle est disponible."""

    __gtype_name__ = "TriatCover"

    def __init__(self, size: int = 60, radius: float = 10.0) -> None:
        super().__init__()
        self.add_css_class("triat-cover")
        self._size = size
        self._radius = radius
        self._texture: Gdk.Texture | None = None
        self._pattern = PATTERNS[0]
        self._url: str | None = None
        self._token = 0
        self.set_size_request(size, size)
        self.set_overflow(Gtk.Overflow.HIDDEN)

    # ---- API -------------------------------------------------------------

    def set_size(self, size: int) -> None:
        self._size = size
        self.set_size_request(size, size)
        self.queue_resize()

    def _pixels(self) -> int:
        # Deux fois la taille logique : net sur un écran HiDPI, et toujours
        # bien plus léger que l'image source.
        return max(self._size, 16) * 2

    def set_track(self, ref) -> None:
        """Affiche la pochette d'une piste, ou son motif de repli."""
        url = getattr(ref, "thumbnail", None) if ref else None
        pattern = pattern_for(getattr(ref, "video_id", "") if ref else "")
        if url and url == self._url and self._texture is not None:
            return                      # déjà affichée : rien à refaire
        self._token += 1
        token = self._token
        self._url = url
        self._pattern = pattern
        self._texture = TEXTURES.get(url, self._pixels()) if url else None
        self.queue_draw()
        if url and self._texture is None:
            TEXTURES.request(url, self._pixels(),
                             lambda texture: self._apply(texture, token))

    def clear(self) -> None:
        self._token += 1
        self._texture = None
        self._url = None
        self._pattern = PATTERNS[0]
        self.queue_draw()

    def _apply(self, texture, token: int) -> None:
        # Une autre piste a pu être demandée entre-temps.
        if token != self._token or texture is None:
            return
        self._texture = texture
        self.queue_draw()

    # ---- Rendu -----------------------------------------------------------

    def do_snapshot(self, snapshot: Gtk.Snapshot) -> None:
        width = self.get_width()
        height = self.get_height()
        if width <= 0 or height <= 0:
            return
        side = min(width, height)
        offset_x = (width - side) / 2
        offset_y = (height - side) / 2

        rect = Graphene.Rect().init(offset_x, offset_y, side, side)
        rounded = Gsk.RoundedRect()
        rounded.init_from_rect(rect, self._radius)
        snapshot.push_rounded_clip(rounded)
        if self._texture is not None:
            snapshot.append_texture(self._texture, rect)
        else:
            snapshot.save()
            snapshot.translate(Graphene.Point().init(offset_x, offset_y))
            snapshot.append_node(_placeholder_node(self._pattern, side, self._radius))
            snapshot.restore()
        snapshot.pop()

    def do_measure(self, _orientation, _for_size):
        return (self._size, self._size, -1, -1)

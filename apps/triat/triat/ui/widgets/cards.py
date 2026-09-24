"""Cartes en point-matrice : artiste (rond) et playlist (carré arrondi)."""

from __future__ import annotations

import zlib

import gi

gi.require_version("Gtk", "4.0")

from gi.repository import Gtk

from ...core.search_results import normalize
from .common import label
from .glyph import GlyphArt


def seed_for(text: str) -> int:
    """Graine stable du motif, tirée du nom."""
    return zlib.crc32(normalize(text).encode()) or 1


class ArtistCard(Gtk.Button):
    def __init__(self, name: str, count: int, size: int = 132) -> None:
        super().__init__()
        self.add_css_class("triat-mix")
        self.artist = name
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        art = GlyphArt(grid=11, size=size, radius=size / 2)
        art.add_css_class("round")
        art.set_size_request(size, size)
        art.set_halign(Gtk.Align.START)
        art.set_seed(seed_for(name))
        box.append(art)
        title = label(name, "mix-name", ellipsize=3, max_width_chars=14)
        title.set_margin_top(8)
        box.append(title)
        box.append(label(f"{count} titre" + ("s" if count > 1 else ""),
                         "mix-detail"))
        box.set_size_request(size, -1)
        self.set_child(box)
        self.update_property([Gtk.AccessibleProperty.LABEL], [f"Artiste {name}"])


class PlaylistCard(Gtk.Button):
    def __init__(self, playlist: dict, size: int = 132) -> None:
        super().__init__()
        self.add_css_class("triat-mix")
        self.playlist_id = playlist.get("id")
        name = playlist.get("name", "Playlist")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        art = GlyphArt(grid=11, size=size, radius=20.0)
        art.set_size_request(size, size)
        art.set_halign(Gtk.Align.START)
        art.set_seed(seed_for(name))
        box.append(art)
        title = label(name, "mix-name", ellipsize=3, max_width_chars=14)
        title.set_margin_top(8)
        box.append(title)
        box.append(label(f"{playlist.get('item_count', 0)} titres", "mix-detail"))
        box.set_size_request(size, -1)
        self.set_child(box)
        self.update_property([Gtk.AccessibleProperty.LABEL], [f"Playlist {name}"])

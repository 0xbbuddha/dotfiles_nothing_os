"""Grille de pochettes (screens.md §1).

`Gtk.GridView` + `Gio.ListStore` + factory : les images ne sont chargées
que pour les cellules réellement affichées, condition posée par GTK.md §5
pour tenir des bibliothèques de plusieurs milliers d'entrées.
"""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")

from gi.repository import Gio, GObject, Gtk

from ..core.models import TrackRef
from .widgets.cover import Cover

COVER_SIZE = 148


class GridItem(GObject.Object):
    """Entrée de grille : une piste et un libellé de type facultatif."""

    __gtype_name__ = "TriatGridItem"

    def __init__(self, ref: TrackRef, badge: str = "") -> None:
        super().__init__()
        self.ref = ref
        self.badge = badge


class TrackGrid(Gtk.GridView):
    """Grille de pochettes. Émet `item-activated` avec l'index."""

    __gtype_name__ = "TriatTrackGrid"

    __gsignals__ = {
        "item-activated": (GObject.SignalFlags.RUN_FIRST, None, (int,)),
    }

    def __init__(self, cover_size: int = COVER_SIZE, min_columns: int = 2,
                 max_columns: int = 8) -> None:
        self._store = Gio.ListStore(item_type=GridItem)
        self._cover_size = cover_size
        selection = Gtk.SingleSelection(model=self._store, autoselect=False)
        selection.set_can_unselect(True)

        factory = Gtk.SignalListItemFactory()
        factory.connect("setup", self._on_setup)
        factory.connect("bind", self._on_bind)
        factory.connect("unbind", self._on_unbind)

        super().__init__(model=selection, factory=factory)
        self.add_css_class("triat-grid")
        self.set_min_columns(min_columns)
        self.set_max_columns(max_columns)
        self.set_single_click_activate(True)
        self.connect("activate", lambda _v, pos: self.emit("item-activated", pos))

    # ---- Modèle ----------------------------------------------------------

    def set_items(self, refs, badges=None) -> None:
        """`badges` : libellé par piste (ALBUM, MIX…), ou None."""
        badges = badges or {}
        items = [GridItem(ref, badges.get(ref.video_id, "")) for ref in refs]
        self._store.splice(0, self._store.get_n_items(), items)

    @property
    def items(self) -> list[TrackRef]:
        return [self._store.get_item(i).ref
                for i in range(self._store.get_n_items())]

    def __len__(self) -> int:
        return self._store.get_n_items()

    # ---- Factory ---------------------------------------------------------

    def _on_setup(self, _factory, list_item: Gtk.ListItem) -> None:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.add_css_class("triat-grid-item")

        cover = Cover(size=self._cover_size, radius=6.0)
        box.append(cover)

        title = Gtk.Label(xalign=0, ellipsize=3, max_width_chars=18)
        title.add_css_class("triat-body")
        box.append(title)

        artist = Gtk.Label(xalign=0, ellipsize=3, max_width_chars=20)
        artist.add_css_class("triat-body")
        artist.add_css_class("triat-dim")
        box.append(artist)

        list_item.set_child(box)
        list_item._parts = (cover, title, artist)

    def _on_bind(self, _factory, list_item: Gtk.ListItem) -> None:
        item = list_item.get_item()
        cover, title, artist = list_item._parts
        cover.set_track(item.ref)
        title.set_text(item.ref.title)
        # Le libellé de type remplace l'artiste quand il y en a un.
        artist.set_text(item.badge if item.badge
                        else (item.ref.artist or "—"))
        if item.badge:
            artist.add_css_class("triat-label")
        else:
            artist.remove_css_class("triat-label")

    @staticmethod
    def _on_unbind(_factory, list_item: Gtk.ListItem) -> None:
        # Libère la texture : une grille défilée longtemps ne doit pas
        # garder en mémoire toutes les pochettes rencontrées.
        cover, _title, _artist = list_item._parts
        cover.clear()

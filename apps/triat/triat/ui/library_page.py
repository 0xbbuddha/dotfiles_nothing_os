"""Écran Bibliothèque (screens.md §8, maquette `Library.dc.html`).

Puces Playlists / Artistes / Favoris / Historique. L'onglet Playlists
montre les smart playlists (`core/smart.py`) puis les playlists de
l'utilisateur ; un clic ouvre la vue détail, avec retour.
"""

from __future__ import annotations

import logging
import random
import threading

import gi

gi.require_version("Adw", "1")
gi.require_version("Gtk", "4.0")

from gi.repository import Adw, Gio, GLib, Gtk

from ..core.importer import (ImportError_,
                             export_playlist, import_playlist)
from ..core.smart import smart_playlists
from .track_list import TrackList
from .widgets.cards import ArtistCard, seed_for
from .widgets.common import EmptyState, SectionTitle, label
from .widgets.glyph import GlyphArt

log = logging.getLogger(__name__)

TABS = (("playlists", "Playlists"), ("artists", "Artistes"),
        ("favorites", "Favoris"), ("history", "Historique"))


def _plural(count: int, noun: str) -> str:
    return f"{count} {noun}{'s' if count > 1 else ''}"


def _total(seconds: float) -> str:
    """Durée d'une playlist : « 3 h 12 », « 47 min »."""
    minutes = int(seconds // 60)
    if minutes >= 60:
        return f"{minutes // 60} h {minutes % 60:02d}"
    return f"{minutes} min"


def _known_total(refs) -> float:
    """Durée totale, seulement si presque toutes les durées sont connues.

    Les pistes importées par oEmbed n'en ont pas : additionner les rares
    connues afficherait « 19 min » pour 217 titres."""
    known = [r.duration for r in refs if r.duration]
    return sum(known) if refs and len(known) >= 0.9 * len(refs) else 0.0


def _pill(text: str, primary: bool = False) -> Gtk.Button:
    button = Gtk.Button(label=text)
    button.add_css_class("pill")
    if primary:
        button.add_css_class("suggested-action")
    button.set_valign(Gtk.Align.CENTER)
    return button


def _quiet(text: str) -> Gtk.Button:
    """Action secondaire : texte seul, pour ne pas concurrencer « Tout lire »."""
    button = Gtk.Button(label=text)
    button.add_css_class("flat")
    button.set_valign(Gtk.Align.CENTER)
    return button


class SmartTile(Gtk.Button):
    """Smart playlist : son nombre de titres en grand, son nom, sa règle.

    Pas de numéro 01–04 : ces listes ne forment pas une suite."""

    def __init__(self, smart) -> None:
        super().__init__()
        self.smart = smart
        self.add_css_class("triat-tile")
        self.add_css_class("triat-smart")
        self.set_hexpand(True)
        self.set_size_request(140, -1)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.count = label("—", "tile-big")
        box.append(self.count)
        name = label(smart.name, "tile-title", ellipsize=3)
        name.set_margin_top(18)
        box.append(name)
        box.append(label(smart.rule, "tile-detail", ellipsize=3))
        self.set_child(box)
        self.update_property([Gtk.AccessibleProperty.LABEL],
                             [f"{smart.name}, {smart.rule}"])

    def set_count(self, count: int) -> None:
        self.count.set_text(str(count))
        self.set_tooltip_text(_plural(count, "titre"))


class PlaylistRow(Gtk.ListBoxRow):
    """Ligne : trame 40, nom et nombre de titres, durée, lecture."""

    def __init__(self, item: dict, on_play) -> None:
        super().__init__()
        self.playlist_id = item["id"]
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.add_css_class("triat-playlist-row")
        box.set_size_request(-1, 54)

        art = GlyphArt(grid=7, size=40, radius=4.0)
        art.add_css_class("small")
        art.set_size_request(40, 40)
        art.set_valign(Gtk.Align.CENTER)
        art.set_seed(seed_for(item["name"]))
        box.append(art)

        count = item.get("item_count", 0)
        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1,
                        valign=Gtk.Align.CENTER, hexpand=True)
        texts.append(label(item["name"], "triat-body", ellipsize=3))
        detail = _plural(count, "titre")
        if item.get("remote_id"):
            detail += ", synchronisée avec YouTube"
        texts.append(label(detail, "triat-dim"))
        box.append(texts)

        complete = count and item.get("known_durations", 0) >= 0.9 * count
        if complete:
            box.append(label(_total(item.get("total_duration") or 0),
                             "triat-mono", xalign=1))

        play = Gtk.Button(icon_name="triat-play-symbolic")
        play.add_css_class("flat")
        play.add_css_class("circular")
        play.set_valign(Gtk.Align.CENTER)
        play.set_tooltip_text(f"Lire « {item['name']} »")
        play.update_property([Gtk.AccessibleProperty.LABEL],
                             [f"Lire {item['name']}"])
        play.connect("clicked", lambda *_: on_play(item["id"]))
        box.append(play)
        self.set_child(box)


class LibraryPage(Gtk.Box):
    def __init__(self, engine, on_play, toaster=None, on_action=None,
                 on_artist=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-content")
        self._engine = engine
        self._on_play = on_play
        self._toaster = toaster
        self._on_action = on_action
        self._on_artist = on_artist
        self._playlist_ids: list[int] = []
        self._detail_id: int | None = None        # playlist ouverte, sinon smart
        self._detail_smart = None
        self._detail_refs = []

        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        column.set_margin_bottom(24)

        # --- En-tête : titre, puces, actions ---
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        title = label("Bibliothèque", "triat-display", "lg", hexpand=True)
        header.append(title)
        self.import_button = _pill("Importer")
        self.import_button.set_tooltip_text("Fichier .txt d'URL YouTube, .m3u ou .m3u8")
        self.import_button.connect("clicked", self._choose_file)
        header.append(self.import_button)
        self.new_button = _pill("Nouvelle playlist", primary=True)
        self.new_button.connect("clicked", self._ask_new_playlist)
        header.append(self.new_button)
        column.append(header)

        self.tabs = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self._tab_buttons: dict[str, Gtk.ToggleButton] = {}
        first = None
        for key, text in TABS:
            button = Gtk.ToggleButton()
            button.add_css_class("triat-chip")
            inner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            dot = Gtk.Box()
            dot.add_css_class("triat-chip-dot")
            dot.set_valign(Gtk.Align.CENTER)
            inner.append(dot)
            inner.append(Gtk.Label(label=text))
            button.set_child(inner)
            button.update_property([Gtk.AccessibleProperty.LABEL], [text])
            if first is None:
                first = button
                button.set_active(True)
            else:
                button.set_group(first)
            button.connect("toggled", self._on_tab, key)
            self._tab_buttons[key] = button
            self.tabs.append(button)
        column.append(self.tabs)

        self.status = label("", "triat-dim")
        column.append(self.status)

        self.views = Gtk.Stack(vexpand=True)
        self.views.set_transition_type(Gtk.StackTransitionType.NONE)
        column.append(self.views)
        self.append(column)

        # --- Vue d'ensemble des playlists ---
        overview = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        overview.append(SectionTitle("Smart playlists"))
        # FlowBox : quatre tuiles sur une ligne quand il y a la place, deux
        # sinon. Une Box homogène imposait 580 px de large à la fenêtre.
        self.smart_row = Gtk.FlowBox(homogeneous=True, column_spacing=10,
                                     row_spacing=10, min_children_per_line=2,
                                     max_children_per_line=4,
                                     selection_mode=Gtk.SelectionMode.NONE)
        overview.append(self.smart_row)
        self.smarts = smart_playlists(engine.library, engine.downloads)
        self.smart_tiles = []
        for smart in self.smarts:
            tile = SmartTile(smart)
            self.smart_tiles.append(tile)
            tile.connect("clicked", self._open_smart)
            self.smart_row.append(tile)

        mine = SectionTitle("Vos playlists")
        mine.set_margin_top(14)
        overview.append(mine)
        self.playlists = Gtk.ListBox()
        self.playlists.add_css_class("triat-playlists")
        self.playlists.set_selection_mode(Gtk.SelectionMode.NONE)
        self.playlists.connect("row-activated", self._on_playlist_row)
        overview.append(self.playlists)
        self.playlists_empty = EmptyState(
            "Aucune playlist",
            "Importez un fichier .txt d'URL YouTube ou .m3u, "
            "ou créez une playlist vide.")
        overview.append(self.playlists_empty)
        self.views.add_named(self._scrolled(overview), "playlists")

        # --- Détail d'une playlist ---
        detail = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        heading = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        back = Gtk.Button(icon_name="triat-back-symbolic")
        back.add_css_class("flat")
        back.add_css_class("circular")
        back.set_valign(Gtk.Align.CENTER)
        back.set_tooltip_text("Retour aux playlists")
        back.update_property([Gtk.AccessibleProperty.LABEL], ["Retour"])
        back.connect("clicked", lambda *_: self.close_detail())
        heading.append(back)
        self.detail_title = label("", "triat-display", "sm", ellipsize=3,
                                  hexpand=True)
        heading.append(self.detail_title)
        detail.append(heading)
        self.detail_meta = label("", "triat-dim")
        self.detail_meta.set_margin_start(42)
        detail.append(self.detail_meta)
        actions = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE,
                              column_spacing=6, row_spacing=6,
                              max_children_per_line=6)
        actions.set_halign(Gtk.Align.START)
        actions.set_margin_start(42)
        actions.set_margin_top(8)
        actions.set_margin_bottom(8)
        self.play_all = _pill("Tout lire", primary=True)
        self.play_all.connect("clicked", lambda *_: self._play_detail(False))
        actions.append(self.play_all)
        self.shuffle = _pill("Aléatoire")
        self.shuffle.connect("clicked", lambda *_: self._play_detail(True))
        actions.append(self.shuffle)
        self.export_button = _quiet("Exporter")
        self.export_button.set_tooltip_text(
            "Enregistrer en .m3u8, .txt, .json ou .csv")
        self.export_button.connect("clicked", self._choose_export)
        actions.append(self.export_button)
        self.rename_button = _quiet("Renommer")
        self.rename_button.connect("clicked", self._ask_rename)
        actions.append(self.rename_button)
        self.delete_button = _quiet("Supprimer")
        self.delete_button.add_css_class("destructive-action")
        self.delete_button.connect("clicked", self._ask_delete)
        actions.append(self.delete_button)
        detail.append(actions)
        self.tracks = TrackList()
        self.tracks.connect("track-activated", self._on_track_activated)
        self.tracks.connect("track-action", self._relay_action)
        detail.append(self._scrolled(self.tracks))
        self.views.add_named(detail, "detail")

        # --- Artistes ---
        self.artists = Gtk.FlowBox(column_spacing=8, row_spacing=8,
                                   max_children_per_line=8)
        self.artists.set_selection_mode(Gtk.SelectionMode.NONE)
        self.artists.set_valign(Gtk.Align.START)
        self.views.add_named(self._scrolled(self.artists), "artists")

        # --- Favoris, historique ---
        self.plain = TrackList()
        self.plain.connect("track-activated", self._on_track_activated)
        self.plain.connect("track-action", self._relay_action)
        self.views.add_named(self._scrolled(self.plain), "tracks")

        engine.connect("library-changed", lambda *_: self._on_library_changed())
        self.refresh()

    def _on_library_changed(self) -> None:
        if self.get_mapped():
            self.refresh()

    @staticmethod
    def _scrolled(child: Gtk.Widget) -> Gtk.ScrolledWindow:
        scroller = Gtk.ScrolledWindow(vexpand=True, hexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(child)
        return scroller

    # ---- Contenu ---------------------------------------------------------

    @property
    def active_tab(self) -> str:
        return next((k for k, b in self._tab_buttons.items() if b.get_active()),
                    "playlists")

    def refresh(self) -> None:
        key = self.active_tab
        if key == "playlists" and self.views.get_visible_child_name() == "detail":
            self._reload_detail()
            return
        self._on_tab(self._tab_buttons[key], key)

    def _on_tab(self, button, key: str) -> None:
        if not button.get_active():
            return
        if key == "playlists":
            self._load_playlists()
            self.views.set_visible_child_name("playlists")
        elif key == "artists":
            self._load_artists()
            self.views.set_visible_child_name("artists")
        else:
            refs = (self._engine.library.list_favorites(limit=500)
                    if key == "favorites"
                    else self._engine.library.recent(limit=500))
            self.plain.set_tracks(refs)
            noun = "favori" if key == "favorites" else "écoute"
            self.status.set_text(_plural(len(refs), noun) if refs
                                 else "Rien ici pour l'instant")
            self.views.set_visible_child_name("tracks")
        self._mark_current()

    def _load_playlists(self) -> None:
        self.playlists.remove_all()
        items = self._engine.library.list_playlists()
        self._playlist_ids = [item["id"] for item in items]
        self.playlists.set_visible(bool(items))
        self.playlists_empty.set_visible(not items)
        total = sum(item["item_count"] for item in items)
        self.status.set_text(
            f"{_plural(len(items), 'playlist')}, {_plural(total, 'piste')}"
            if items else "")
        for tile in self.smart_tiles:
            tile.set_count(len(tile.smart.fetch()))
        for item in items:
            self.playlists.append(PlaylistRow(item, self._play_playlist))

    def _load_artists(self) -> None:
        self.artists.remove_all()
        artists = self._engine.library.artists(limit=200, owned=True)
        self.status.set_text(_plural(len(artists), "artiste") if artists
                             else "Aucun artiste pour l'instant")
        for name, count in artists:
            card = ArtistCard(name, count, size=120)
            card.connect("clicked", self._open_artist)
            self.artists.append(card)

    # ---- Détail ----------------------------------------------------------

    def show_playlist(self, playlist_id: int) -> None:
        """Ouvre une playlist précise (depuis la recherche ou la sidebar)."""
        self._tab_buttons["playlists"].set_active(True)
        self._load_playlists()
        if playlist_id in self._playlist_ids:
            self._open_detail(playlist_id=playlist_id)

    def _on_playlist_row(self, _box, row) -> None:
        self._open_detail(playlist_id=row.playlist_id)

    def _open_smart(self, tile) -> None:
        self._open_detail(smart=tile.smart)

    def _open_detail(self, playlist_id: int | None = None, smart=None) -> None:
        self._detail_id = playlist_id
        self._detail_smart = smart
        self._reload_detail()
        self.views.set_visible_child_name("detail")

    def _reload_detail(self) -> None:
        library = self._engine.library
        if self._detail_id is not None:
            item = next((p for p in library.list_playlists()
                         if p["id"] == self._detail_id), None)
            if item is None:            # supprimée entre-temps
                self.close_detail()
                return
            name = item["name"]
            refs = library.playlist_items(self._detail_id)
            origin = ("synchronisée avec YouTube" if item.get("remote_id")
                      else "playlist locale")
        else:
            name = self._detail_smart.name
            refs = self._detail_smart.fetch()
            origin = self._detail_smart.rule
        self._detail_refs = refs
        self.detail_title.set_text(name)
        meta = [_plural(len(refs), "titre"), origin]
        seconds = _known_total(refs)
        if seconds:
            meta.insert(1, _total(seconds))
        self.detail_meta.set_text(", ".join(meta))
        self.status.set_text("")
        editable = self._detail_id is not None
        self.rename_button.set_visible(editable)
        self.delete_button.set_visible(editable)
        for button in (self.play_all, self.shuffle, self.export_button):
            button.set_sensitive(bool(refs))
        self.tracks.set_tracks(refs)
        self._mark_current()

    def close_detail(self) -> None:
        self._detail_id = None
        self._load_playlists()
        self.views.set_visible_child_name("playlists")

    def _mark_current(self) -> None:
        current = self._engine.current
        video_id = current.video_id if current else None
        self.tracks.set_current(video_id)
        self.plain.set_current(video_id)

    # ---- Lecture ---------------------------------------------------------

    def _play_playlist(self, playlist_id: int) -> None:
        refs = self._engine.library.playlist_items(playlist_id)
        if refs:
            self._on_play(refs, 0)

    def _play_detail(self, shuffled: bool) -> None:
        refs = list(self._detail_refs)
        if not refs:
            return
        if shuffled:
            random.shuffle(refs)
        self._on_play(refs, 0)

    def _on_track_activated(self, track_list, position: int) -> None:
        refs = track_list.tracks
        if 0 <= position < len(refs):
            self._on_play(refs, position)

    def _relay_action(self, track_list, action: str, position: int) -> None:
        refs = track_list.tracks
        if self._on_action and 0 <= position < len(refs):
            self._on_action(action, refs[position])

    def _open_artist(self, card) -> None:
        if self._on_artist:
            self._on_artist(card.artist)

    # ---- Créer, renommer, supprimer --------------------------------------

    def _name_dialog(self, heading: str, initial: str, confirm: str, done) -> None:
        dialog = Adw.AlertDialog(heading=heading)
        entry = Gtk.Entry(text=initial, activates_default=True)
        dialog.set_extra_child(entry)
        dialog.add_response("cancel", "Annuler")
        dialog.add_response("ok", confirm)
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("ok")
        dialog.set_close_response("cancel")

        def on_response(_dialog, response: str) -> None:
            name = entry.get_text().strip()
            if response == "ok" and name:
                done(name)

        dialog.connect("response", on_response)
        dialog.present(self.get_root())

    def _ask_new_playlist(self, _button) -> None:
        def create(name: str) -> None:
            playlist_id = self._engine.library.create_playlist(name)
            self.show_playlist(playlist_id)
            self._notify_sidebar()

        self._name_dialog("Nouvelle playlist", "", "Créer", create)

    def _ask_rename(self, _button) -> None:
        if self._detail_id is None:
            return
        playlist_id = self._detail_id

        def rename(name: str) -> None:
            self._engine.library.rename_playlist(playlist_id, name)
            self._reload_detail()
            self._notify_sidebar()

        self._name_dialog("Renommer la playlist",
                          self.detail_title.get_text(), "Renommer", rename)

    def _ask_delete(self, _button) -> None:
        if self._detail_id is None:
            return
        playlist_id = self._detail_id
        name = self.detail_title.get_text()
        dialog = Adw.AlertDialog(
            heading=f"Supprimer « {name} » ?",
            body="La playlist disparaît ; les pistes restent dans la bibliothèque.")
        dialog.add_response("cancel", "Annuler")
        dialog.add_response("delete", "Supprimer")
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_close_response("cancel")

        def on_response(_dialog, response: str) -> None:
            if response == "delete":
                self._engine.library.delete_playlist(playlist_id)
                self.close_detail()
                self._notify_sidebar()
                if self._toaster:
                    self._toaster(f"« {name} » supprimée")

        dialog.connect("response", on_response)
        dialog.present(self.get_root())

    def _notify_sidebar(self) -> None:
        root = self.get_root()
        if root is not None and hasattr(root, "refresh_sidebar"):
            root.refresh_sidebar()

    # ---- Export ----------------------------------------------------------

    def _choose_export(self, _button) -> None:
        if not self._detail_refs:
            if self._toaster:
                self._toaster("Rien à exporter")
            return
        dialog = Gtk.FileDialog(title="Exporter la playlist")
        base = self.detail_title.get_text() or "playlist"
        dialog.set_initial_name(f"{base}.m3u8")
        dialog.save(self.get_root(), None, self._on_export_chosen)

    def _on_export_chosen(self, dialog, result) -> None:
        try:
            file = dialog.save_finish(result)
        except GLib.Error:
            return
        if file is None or not file.get_path():
            return
        refs = self._detail_refs
        try:
            path = export_playlist(refs, file.get_path())
        except Exception as exc:
            if self._toaster:
                self._toaster(f"Export impossible : {exc}")
            return
        if self._toaster:
            self._toaster(f"{len(refs)} pistes exportées vers {path.name}")

    # ---- Import ----------------------------------------------------------

    def _choose_file(self, _button) -> None:
        dialog = Gtk.FileDialog(title="Importer une playlist")
        filters = Gio.ListStore(item_type=Gtk.FileFilter)
        playlist_filter = Gtk.FileFilter()
        playlist_filter.set_name("Playlists (.txt, .m3u, .m3u8)")
        for pattern in ("*.txt", "*.m3u", "*.m3u8"):
            playlist_filter.add_pattern(pattern)
        filters.append(playlist_filter)
        every = Gtk.FileFilter()
        every.set_name("Tous les fichiers")
        every.add_pattern("*")
        filters.append(every)
        dialog.set_filters(filters)
        dialog.open(self.get_root(), None, self._on_file_chosen)

    def _on_file_chosen(self, dialog, result) -> None:
        try:
            file = dialog.open_finish(result)
        except GLib.Error:
            return          # l'utilisateur a annulé
        if file is None or not file.get_path():
            return
        self.start_import(file.get_path())

    def start_import(self, path: str) -> None:
        """Importe en arrière-plan, l'interface reste réactive."""
        self.import_button.set_sensitive(False)
        self.status.set_text("import en cours…")

        def worker() -> None:
            try:
                pid, name, refs = import_playlist(path, self._engine.library)
            except ImportError_ as exc:
                GLib.idle_add(self._import_done, None, None, 0, str(exc))
                return
            except Exception as exc:
                log.exception("Import impossible")
                GLib.idle_add(self._import_done, None, None, 0, str(exc))
                return
            GLib.idle_add(self._import_done, pid, name, len(refs), None)

        threading.Thread(target=worker, daemon=True).start()

    def _import_done(self, playlist_id, name, count: int, error) -> bool:
        self.import_button.set_sensitive(True)
        if error:
            self.status.set_text("import échoué")
            if self._toaster is not None:
                self._toaster(f"Import impossible : {error}")
            return GLib.SOURCE_REMOVE
        if playlist_id is not None:
            self.show_playlist(playlist_id)
        else:
            self._tab_buttons["playlists"].set_active(True)
            self._load_playlists()
        self._notify_sidebar()
        self._engine.backfill_durations_async()
        if self._toaster is not None:
            self._toaster(f"« {name} » importée : {count} pistes")
        return GLib.SOURCE_REMOVE

"""Page Recherche (screens.md §2, maquette `Search.dc.html`).

Puces Tout / Titres / Artistes / Playlists, carte « Meilleur résultat »,
cinq premiers titres, artistes et playlists locales. Albums et Clips de la
maquette sont absents : YouTube Music ne répond plus aux recherches
filtrées (voir `core/search_results.py`).
"""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gdk, Gtk

from ..core import search_results
from .track_list import TrackList
from .widgets.cards import ArtistCard, PlaylistCard, seed_for
from .widgets.common import EmptyState, SectionTitle, label
from .widgets.glyph import GlyphArt

FILTERS = (("all", "Tout"), ("tracks", "Titres"),
           ("artists", "Artistes"), ("playlists", "Playlists"))
TOP_TRACKS = 5
BADGES = {"artist": "Artiste", "playlist": "Playlist", "track": "Titre"}


def _flow() -> Gtk.FlowBox:
    flow = Gtk.FlowBox(homogeneous=False, column_spacing=8, row_spacing=8)
    flow.set_selection_mode(Gtk.SelectionMode.NONE)
    flow.set_max_children_per_line(8)
    flow.set_valign(Gtk.Align.START)
    return flow


class BestCard(Gtk.Button):
    """Carte « Meilleur résultat » : trame ronde, nom en Doto, badge."""

    def __init__(self) -> None:
        super().__init__()
        self.add_css_class("triat-tile")
        self.add_css_class("triat-best")
        self.set_size_request(400, 280)
        self.set_valign(Gtk.Align.START)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        self.art = GlyphArt(grid=15, size=128, radius=64.0)
        self.art.add_css_class("round")
        self.art.set_size_request(128, 128)
        self.art.set_halign(Gtk.Align.START)
        box.append(self.art)
        self.name = label("", "triat-display", "sm", ellipsize=3,
                          max_width_chars=16)
        box.append(self.name)
        meta = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        self.badge = label("", "triat-badge")
        meta.append(self.badge)
        self.detail = label("", "tile-detail", ellipsize=3, max_width_chars=28)
        meta.append(self.detail)
        box.append(meta)
        self.set_child(box)
        self.best = None

    def show(self, best) -> None:
        self.best = best
        if best.kind == "track":
            self.art.set_track(best.ref)
        else:
            self.art.set_seed(seed_for(best.title))
        self.name.set_text(best.title)
        self.badge.set_text(BADGES.get(best.kind, ""))
        self.detail.set_text(best.detail)
        self.update_property([Gtk.AccessibleProperty.LABEL],
                             [f"Meilleur résultat : {best.title}, "
                              f"{BADGES.get(best.kind, '')}"])


class SearchPage(Gtk.Box):
    """Recherche et résultats (screens.md §2)."""

    def __init__(self, engine, on_play, on_action=None, on_artist=None,
                 on_playlist=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-content")
        self._engine = engine
        self._on_play = on_play
        self._on_action = on_action
        self._on_artist = on_artist
        self._on_playlist = on_playlist
        self.results_data = None

        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        column.set_margin_bottom(24)

        self.entry = Gtk.SearchEntry(
            placeholder_text="Titre, artiste, ou URL YouTube collée…",
            hexpand=True)
        # Au plus 560 px, mais sans minimum imposé : la fenêtre tuilée
        # peut descendre sous 500 px.
        self.entry.set_size_request(200, -1)
        self.entry.set_halign(Gtk.Align.FILL)
        self.entry.connect("activate", lambda *_: self.run_search())
        self.entry.connect("stop-search", self._on_escape)
        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._on_entry_key)
        self.entry.add_controller(keys)
        clamp = Adw.Clamp(maximum_size=560, tightening_threshold=560,
                          child=self.entry)
        clamp.set_halign(Gtk.Align.START)
        clamp.set_hexpand(True)
        column.append(clamp)

        # --- Puces de filtre ---
        self.chips = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.chips.update_property([Gtk.AccessibleProperty.LABEL], ["Filtres"])
        self._chip_buttons: dict[str, Gtk.ToggleButton] = {}
        first = None
        for key, text in FILTERS:
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
            button.connect("toggled", self._on_chip, key)
            self._chip_buttons[key] = button
            self.chips.append(button)
        self.chips.set_visible(False)
        column.append(self.chips)

        # --- État vide : historique, puis messages ---
        self.empty = EmptyState(
            "Aucune recherche",
            "Tapez un titre, un artiste, ou collez une URL youtube.com.")
        column.append(self.empty)
        self.history_title = SectionTitle("Recherches récentes")
        self.history = _flow()
        column.append(self.history_title)
        column.append(self.history)

        # --- Résultats, une page par filtre ---
        self.views = Gtk.Stack(vexpand=True)
        self.views.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.views.set_visible(False)
        column.append(self.views)

        # Tout
        overview = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=28)
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=24)
        best_column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        best_column.append(SectionTitle("Meilleur résultat"))
        self.best_card = BestCard()
        self.best_card.connect("clicked", self._open_best)
        best_column.append(self.best_card)
        self.best_column = best_column
        top.append(best_column)
        tracks_column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14,
                                hexpand=True)
        tracks_column.append(SectionTitle(
            "Titres", "Tout voir", lambda: self.select_filter("tracks")))
        self.top_tracks = TrackList()
        self.top_tracks.set_vexpand(False)
        self.top_tracks.connect("track-activated", self._on_activated)
        self.top_tracks.connect("track-action", self._relay_action)
        tracks_column.append(self.top_tracks)
        top.append(tracks_column)
        overview.append(top)

        self.artists_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                       spacing=14)
        self.artists_section.append(SectionTitle(
            "Artistes", "Tout voir", lambda: self.select_filter("artists")))
        self.overview_artists = _flow()
        self.artists_section.append(self.overview_artists)
        overview.append(self.artists_section)

        self.playlists_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                         spacing=14)
        self.playlists_section.append(SectionTitle("Vos playlists"))
        self.overview_playlists = _flow()
        self.playlists_section.append(self.overview_playlists)
        overview.append(self.playlists_section)
        self.views.add_named(self._scrolled(overview), "all")

        # Titres
        self.results = TrackList()
        self.results.connect("track-activated", self._on_activated)
        self.results.connect("track-action", self._relay_action)
        self.views.add_named(self._scrolled(self.results), "tracks")

        # Artistes, playlists
        self.all_artists = _flow()
        self.views.add_named(self._scrolled(self.all_artists), "artists")
        self.all_playlists = _flow()
        self.views.add_named(self._scrolled(self.all_playlists), "playlists")

        self.append(column)
        self._show_history()

    @staticmethod
    def _scrolled(child: Gtk.Widget) -> Gtk.ScrolledWindow:
        scroller = Gtk.ScrolledWindow(vexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(child)
        return scroller

    # ---- Saisie ----------------------------------------------------------

    def focus_entry(self) -> None:
        self.entry.grab_focus()

    def _on_escape(self, _entry) -> None:
        self.entry.set_text("")
        self.results_data = None
        self._show_history()

    def _on_entry_key(self, _ctrl, keyval, _code, _state) -> bool:
        if keyval != Gdk.KEY_Down or not self.views.get_visible():
            return False
        target = (self.top_tracks if self.views.get_visible_child_name() == "all"
                  else self.views.get_visible_child())
        target.child_focus(Gtk.DirectionType.TAB_FORWARD)
        return True

    def run_search(self, query: str | None = None) -> None:
        if query is not None:
            self.entry.set_text(query)
        query = self.entry.get_text().strip()
        if not query:
            return
        self._remember(query)
        self._show_message("Recherche en cours…", "")
        self._engine.search_all_async(query, self._on_results)

    def _remember(self, query: str) -> None:
        settings = getattr(self._engine, "settings", None)
        if settings is None or settings.get("private_session"):
            return
        settings.set("search_history", search_results.remember_query(
            settings.get("search_history"), query))

    # ---- Résultats -------------------------------------------------------

    def _on_results(self, results, error: str | None) -> None:
        if error:
            self._show_message("Recherche impossible", error)
            return
        if results is None or results.empty:
            self._show_message("Aucun résultat", "Essayez d'autres mots.")
            return
        self.results_data = results
        tracks = results.tracks
        self.results.set_tracks(tracks)
        self.top_tracks.set_tracks(tracks[:TOP_TRACKS])

        self.best_column.set_visible(results.best is not None)
        if results.best is not None:
            self.best_card.show(results.best)

        self._fill(self.overview_artists,
                   [ArtistCard(n, c) for n, c in results.artists[:6]])
        self._fill(self.all_artists,
                   [ArtistCard(n, c) for n, c in results.artists])
        self.artists_section.set_visible(bool(results.artists))
        self._fill(self.overview_playlists,
                   [PlaylistCard(p) for p in results.playlists[:6]])
        self._fill(self.all_playlists,
                   [PlaylistCard(p) for p in results.playlists])
        self.playlists_section.set_visible(bool(results.playlists))
        self._chip_buttons["playlists"].set_sensitive(bool(results.playlists))
        self._chip_buttons["artists"].set_sensitive(bool(results.artists))

        self.empty.set_visible(False)
        self.history_title.set_visible(False)
        self.history.set_visible(False)
        self.chips.set_visible(True)
        self.views.set_visible(True)
        self.select_filter("all")

    def _fill(self, flow: Gtk.FlowBox, cards) -> None:
        flow.remove_all()
        for card in cards:
            if isinstance(card, ArtistCard):
                card.connect("clicked", self._open_artist)
            else:
                card.connect("clicked", self._open_playlist)
            flow.append(card)

    def select_filter(self, key: str) -> None:
        button = self._chip_buttons.get(key)
        if button is None:
            return
        if not button.get_active():
            button.set_active(True)          # déclenche _on_chip
        else:
            self.views.set_visible_child_name(key)

    def _on_chip(self, button, key: str) -> None:
        if button.get_active():
            self.views.set_visible_child_name(key)

    def _show_message(self, title: str, detail: str) -> None:
        self.views.set_visible(False)
        self.chips.set_visible(False)
        self.history_title.set_visible(False)
        self.history.set_visible(False)
        self.empty.set_visible(True)
        self.empty.set_message(title, detail)

    def _show_history(self) -> None:
        self._show_message(
            "Aucune recherche",
            "Tapez un titre, un artiste, ou collez une URL youtube.com.")
        settings = getattr(self._engine, "settings", None)
        history = search_results.clean_history(
            settings.get("search_history") if settings else [])
        self.history.remove_all()
        for query in history:
            chip = Gtk.Button(label=query)
            chip.add_css_class("triat-chip")
            chip.connect("clicked", lambda _b, q=query: self.run_search(q))
            self.history.append(chip)
        self.history_title.set_visible(bool(history))
        self.history.set_visible(bool(history))

    # ---- Actions ---------------------------------------------------------

    def _open_best(self, card) -> None:
        best = card.best
        if best is None:
            return
        if best.kind == "artist" and self._on_artist:
            self._on_artist(best.title)
        elif best.kind == "playlist" and self._on_playlist:
            self._on_playlist(best.playlist_id)
        elif best.kind == "track" and self.results_data:
            self._on_play(self.results_data.tracks, 0)

    def _open_artist(self, card) -> None:
        if self._on_artist:
            self._on_artist(card.artist)

    def _open_playlist(self, card) -> None:
        if self._on_playlist and card.playlist_id is not None:
            self._on_playlist(card.playlist_id)

    def _on_activated(self, _list, position: int) -> None:
        refs = self.results_data.tracks if self.results_data else []
        if 0 <= position < len(refs):
            self._on_play(refs, position)

    def _relay_action(self, _list, action: str, position: int) -> None:
        refs = self.results_data.tracks if self.results_data else []
        if self._on_action and 0 <= position < len(refs):
            self._on_action(action, refs[position])


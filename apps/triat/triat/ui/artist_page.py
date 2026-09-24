"""Page Artiste (screens.md §3, adaptée).

Les API YouTube Music étant fermées, la page se construit sur ce que Triat
connaît déjà — les pistes locales de l'artiste — complété par une recherche
en arrière-plan. Elle reste donc utile hors ligne.
"""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")

from gi.repository import Gtk

from .track_list import TrackList
from .widgets.cards import seed_for
from .widgets.glyph import GlyphArt


def _label(text: str, *css: str, **kwargs) -> Gtk.Label:
    widget = Gtk.Label(label=text, xalign=0, **kwargs)
    for name in css:
        widget.add_css_class(name)
    return widget


class ArtistPage(Gtk.Box):
    def __init__(self, engine, on_play, on_action=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-content")
        self._engine = engine
        self._on_play = on_play
        self._on_action = on_action
        self._artist = ""

        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        column.set_margin_bottom(24)

        # En-tête : la trame ronde de l'artiste (même motif que dans la
        # recherche), son nom, ce qu'on a de lui, et deux actions.
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        self.art = GlyphArt(grid=15, size=112, radius=56.0)
        self.art.add_css_class("round")
        self.art.set_size_request(112, 112)
        self.art.set_valign(Gtk.Align.CENTER)
        head.append(self.art)
        words = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4,
                        valign=Gtk.Align.CENTER)
        self.name = _label("", "triat-display", "lg")
        self.name.set_ellipsize(3)
        self.name.set_max_width_chars(26)
        words.append(self.name)
        self.status = _label("", "triat-dim")
        words.append(self.status)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        actions.set_margin_top(10)
        self.play_all = Gtk.Button(label="Tout lire")
        self.play_all.add_css_class("suggested-action")
        self.play_all.connect("clicked", self._play_all)
        actions.append(self.play_all)
        self.radio = Gtk.Button(label="Radio")
        self.radio.add_css_class("pill")
        self.radio.set_tooltip_text("Enchaîne sur des titres proches")
        self.radio.connect("clicked", self._start_radio)
        actions.append(self.radio)
        words.append(actions)
        head.append(words)
        head.set_margin_bottom(10)
        column.append(head)

        self.tracks = TrackList()
        self.tracks.connect("track-activated", self._on_activated)
        self.tracks.connect("track-action", self._relay_action)
        scroller = Gtk.ScrolledWindow(vexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(self.tracks)
        column.append(scroller)

        outer = Gtk.ScrolledWindow(hexpand=True, vexpand=True)
        outer.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        outer.set_child(column)
        self.append(outer)

    # ---- Contenu ---------------------------------------------------------

    def show_artist(self, artist: str) -> None:
        self._artist = (artist or "").strip()
        self.name.set_text(self._artist or "Artiste inconnu")
        self.art.set_seed(seed_for(self._artist or "?"))
        local = self._engine.library.tracks_by_artist(self._artist)
        self.tracks.set_tracks(local)
        self.status.set_text(
            f"{len(local)} piste{'s' if len(local) > 1 else ''} en bibliothèque"
            if local else "Aucune piste en bibliothèque")
        self.play_all.set_sensitive(bool(local))
        self.radio.set_sensitive(bool(local))
        self._mark_current()

        # Complète en ligne sans bloquer, si la bibliothèque est maigre.
        if len(local) < 5 and self._artist:
            self._engine.search_async(self._artist, self._on_found)

    def _on_found(self, refs, error) -> None:
        if error or not refs:
            return
        known = {t.video_id for t in self.tracks.tracks}
        extra = [r for r in refs if r.video_id not in known]
        if not extra:
            return
        merged = self.tracks.tracks + extra[:20]
        self.tracks.set_tracks(merged)
        self.status.set_text(
            f"{len(merged)} pistes, complété en ligne")
        self.play_all.set_sensitive(True)
        self.radio.set_sensitive(True)
        self._mark_current()

    def _mark_current(self) -> None:
        current = self._engine.current
        self.tracks.set_current(current.video_id if current else None)

    # ---- Actions ---------------------------------------------------------

    def _play_all(self, _button) -> None:
        refs = self.tracks.tracks
        if refs:
            self._on_play(refs, 0)

    def _start_radio(self, _button) -> None:
        refs = self.tracks.tracks
        if refs:
            self._on_play(refs, 0)
            self._engine.settings.set("autoplay_radio", True)

    def _on_activated(self, _list, position: int) -> None:
        refs = self.tracks.tracks
        if 0 <= position < len(refs):
            self._on_play(refs, position)

    def _relay_action(self, _list, action: str, position: int) -> None:
        refs = self.tracks.tracks
        if self._on_action and 0 <= position < len(refs):
            self._on_action(action, refs[position])

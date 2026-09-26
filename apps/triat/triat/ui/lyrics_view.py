"""Affichage des paroles synchronisées (screens.md §5).

La ligne en cours est grande et blanche, les autres s'estompent. Le
défilement suit la lecture. Les textes viennent du service à l'exécution ;
rien n'est stocké dans le code.
"""

from __future__ import annotations

import logging
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk

log = logging.getLogger(__name__)

SCROLL_DURATION = 320      # ms, cohérent avec DESIGN.md §7


class LyricsView(Gtk.Box):
    """Colonne de paroles. Se met à jour au fil de la lecture."""

    def __init__(self, engine) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self._engine = engine
        self._lyrics = None
        self._current = -1
        self._rows: list[Gtk.Label] = []
        self._token = 0
        self._animation = None

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        square = Gtk.Box()
        square.add_css_class("triat-square")
        square.set_size_request(6, 6)
        square.set_valign(Gtk.Align.CENTER)
        header.append(square)
        self._title = Gtk.Label(label="paroles", xalign=0)
        self._title.add_css_class("triat-display")
        self._title.add_css_class("section")
        header.append(self._title)
        rule = Gtk.Box(hexpand=True, valign=Gtk.Align.CENTER)
        rule.add_css_class("triat-rule")
        rule.set_size_request(-1, 1)
        header.append(rule)
        self._source = Gtk.Label(label="", xalign=1)
        self._source.add_css_class("triat-label")
        self._source.add_css_class("triat-dim")
        header.append(self._source)
        self.append(header)
        self.header = header

        self._lines_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self._lines_box.set_margin_top(8)
        self._lines_box.set_margin_bottom(120)

        self._scroller = Gtk.ScrolledWindow(vexpand=True)
        self._scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self._scroller.set_child(self._lines_box)
        self.append(self._scroller)

        self._message = Gtk.Label(label="", xalign=0, wrap=True,
                                  max_width_chars=36, valign=Gtk.Align.START)
        self._message.add_css_class("triat-body")
        self._message.add_css_class("triat-dim")
        self._lines_box.append(self._message)

        if engine is not None:
            engine.connect("track-changed", self._on_track)
            engine.connect("position-changed", self._on_position)

    # ---- Chargement ------------------------------------------------------

    def _on_track(self, _engine, ref) -> None:
        self._token += 1
        token = self._token
        self._lyrics = None
        self._current = -1
        self._clear()
        if ref is None:
            self._show_message("")
            return
        self._show_message("Recherche des paroles…")
        threading.Thread(target=self._load, args=(ref, token),
                         daemon=True).start()

    def _load(self, ref, token: int) -> None:
        try:
            lyrics = self._engine.lyrics.fetch(ref)
        except Exception as exc:
            log.debug("Paroles indisponibles : %s", exc)
            return
        GLib.idle_add(self._apply, lyrics, token)

    def _apply(self, lyrics, token: int) -> bool:
        if token != self._token:
            return GLib.SOURCE_REMOVE
        self._lyrics = lyrics
        self._clear()

        if lyrics.instrumental:
            self._show_message("Morceau instrumental.")
        elif lyrics.lines:
            self._source.set_text(lyrics.source)
            for _stamp, text in lyrics.lines:
                self._lines_box.append(self._make_line(text))
        elif lyrics.plain:
            # Sans horodatage, on affiche le texte sans le suivre.
            self._source.set_text(f"{lyrics.source}, non synchronisé")
            for text in lyrics.plain.splitlines():
                self._lines_box.append(self._make_line(text))
        else:
            self._show_message(
                "Paroles indisponibles pour cette piste.")
        return GLib.SOURCE_REMOVE

    def _make_line(self, text: str) -> Gtk.Label:
        label = Gtk.Label(label=text or "♪", xalign=0, wrap=True,
                          max_width_chars=34)
        label.add_css_class("triat-lyric")
        self._rows.append(label)
        return label

    def _clear(self) -> None:
        while (child := self._lines_box.get_first_child()) is not None:
            self._lines_box.remove(child)
        self._rows = []
        self._source.set_text("")
        self._lines_box.append(self._message)
        self._message.set_visible(False)

    def _show_message(self, text: str) -> None:
        self._message.set_text(text)
        self._message.set_visible(bool(text))

    # ---- Suivi de la lecture ---------------------------------------------

    def _on_position(self, _engine, position: float) -> None:
        if not self._lyrics or not self._lyrics.lines or not self._rows:
            return
        index = self._lyrics.index_at(position)
        if index == self._current or not (0 <= index < len(self._rows)):
            return
        if 0 <= self._current < len(self._rows):
            self._rows[self._current].remove_css_class("current")
        self._current = index
        self._rows[index].add_css_class("current")
        self._scroll_to(index)

    def _scroll_to(self, index: int) -> None:
        """Amène la ligne courante au tiers supérieur, en douceur."""
        row = self._rows[index]
        adjustment = self._scroller.get_vadjustment()
        ok, y = row.translate_coordinates(self._lines_box, 0, 0)
        if not ok:
            return
        target = max(0.0, y - self._scroller.get_height() / 3)
        target = min(target, max(0.0, adjustment.get_upper()
                                 - adjustment.get_page_size()))

        if self._animation is not None:
            self._animation.pause()
        target_obj = Adw.PropertyAnimationTarget.new(adjustment, "value")
        self._animation = Adw.TimedAnimation.new(
            self, adjustment.get_value(), target, SCROLL_DURATION, target_obj)
        self._animation.set_easing(Adw.Easing.EASE_OUT_CUBIC)
        self._animation.play()

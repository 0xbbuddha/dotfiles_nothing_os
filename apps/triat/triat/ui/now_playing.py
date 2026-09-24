"""Écran « Lecture en cours » (screens.md §5).

La pochette tramée en points est l'élément fort : grande, à gauche. À côté,
le titre, l'artiste et les commandes. Dessous, « À suivre » et « Paroles »
en onglets : ils restent accessibles dans une fenêtre tuilée de 950 px, où
l'ancienne mise en page en trois colonnes les masquait.
"""

from __future__ import annotations

from gi.repository import Gtk

from .track_list import TrackList, format_time
from .lyrics_view import LyricsView
from .widgets.common import label
from .widgets.dot_progress import DotProgressBar
from .widgets.dot_volume import DotVolume
from .widgets.glyph import GlyphArt

ART_SIZE = 220
ART_SIZE_WIDE = 300


class NowPlayingView(Gtk.Box):
    """Vue plein écran de la piste en cours."""

    def __init__(self, engine, on_close=None, on_artist=None,
                 on_immersion=None) -> None:
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add_css_class("triat-nowplaying")
        self._engine = engine
        self._on_close = on_close
        self._on_artist = on_artist
        self._on_immersion = on_immersion

        self.append(self._build_header())

        self._body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=28,
                             vexpand=True)
        self._body.set_margin_start(28)
        self._body.set_margin_end(28)
        self._body.set_margin_bottom(20)
        self.append(self._body)

        self._player = self._build_player()
        self._body.append(self._player)
        self._body.append(self._build_tabs())

        # Échap referme, comme la flèche.
        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        if engine is not None:
            self._connect(engine)

    def _on_key(self, _ctrl, keyval, _code, _state) -> bool:
        from gi.repository import Gdk
        if keyval == Gdk.KEY_Escape and self._on_close:
            self._on_close()
            return True
        return False

    # ---- Construction ----------------------------------------------------

    def _build_header(self) -> Gtk.Widget:
        header = Gtk.CenterBox()
        header.set_margin_start(16)
        header.set_margin_end(16)
        header.set_margin_top(10)
        header.set_margin_bottom(6)

        back = Gtk.Button(icon_name="triat-chevron-down-symbolic")
        back.add_css_class("flat")
        back.add_css_class("circular")
        back.set_tooltip_text("Réduire (Ctrl+L)")
        back.update_property([Gtk.AccessibleProperty.LABEL], ["Réduire"])
        back.connect("clicked", lambda *_: self._on_close and self._on_close())
        header.set_start_widget(back)

        self.immersion_button = Gtk.Button(label="Plein écran")
        self.immersion_button.add_css_class("pill")
        self.immersion_button.set_tooltip_text(
            "Clip ou matrice de points, en plein écran (Ctrl+I)")
        self.immersion_button.connect(
            "clicked", lambda *_: self._on_immersion and self._on_immersion())
        header.set_end_widget(self.immersion_button)
        return header

    def _build_player(self) -> Gtk.Widget:
        """Colonne de gauche : trame, titres, commandes."""
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self._player_column = column

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=22)
        self.disc = GlyphArt(grid=30, size=ART_SIZE, radius=6.0)
        self.disc.set_size_request(ART_SIZE, ART_SIZE)
        self.disc.set_valign(Gtk.Align.START)
        top.append(self.disc)

        words = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4,
                        valign=Gtk.Align.END, hexpand=True)
        self._title = label("Rien en lecture", "triat-display", "md",
                            wrap=True, lines=3, ellipsize=3,
                            max_width_chars=28)
        words.append(self._title)
        self._artist = label("", "triat-body", "triat-dim", ellipsize=3)
        artist_button = Gtk.Button(child=self._artist)
        artist_button.add_css_class("flat")
        artist_button.add_css_class("triat-link")
        artist_button.set_halign(Gtk.Align.START)
        artist_button.set_tooltip_text("Voir l'artiste")
        artist_button.connect("clicked", self._open_artist)
        self._artist_button = artist_button
        words.append(artist_button)

        extras = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        extras.set_margin_top(10)
        self.favorite = Gtk.ToggleButton(icon_name="triat-heart-symbolic")
        self.favorite.add_css_class("flat")
        self.favorite.add_css_class("circular")
        self.favorite.set_tooltip_text("Ajouter aux favoris")
        self.favorite.update_property([Gtk.AccessibleProperty.LABEL], ["Favori"])
        self._favorite_handler = self.favorite.connect("toggled", self._on_favorite)
        extras.append(self.favorite)
        # Radio infinie : une puce, pas une carte avec interrupteur.
        self.radio_switch = Gtk.ToggleButton()
        self.radio_switch.add_css_class("triat-chip")
        radio_inner = Gtk.Box(spacing=7)
        radio_dot = Gtk.Box(css_classes=["triat-chip-dot"], valign=Gtk.Align.CENTER)
        radio_inner.append(radio_dot)
        radio_inner.append(Gtk.Label(label="Radio infinie"))
        self.radio_switch.set_child(radio_inner)
        self.radio_switch.set_valign(Gtk.Align.CENTER)
        self.radio_switch.set_tooltip_text(
            "Poursuit la lecture quand la file se vide")
        extras.append(self.radio_switch)
        words.append(extras)
        top.append(words)
        column.append(top)

        # Progression et transport sous la trame, sur toute la colonne.
        self.progress = DotProgressBar(step=6.0, radius=1.5, height=12)
        self.progress.set_hexpand(True)
        self.progress.set_margin_top(22)
        column.append(self.progress)
        times = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self._elapsed = label("0:00", "triat-mono", hexpand=True)
        self._total = label("0:00", "triat-mono", xalign=1)
        times.append(self._elapsed)
        times.append(self._total)
        column.append(times)

        controls = Gtk.CenterBox()
        controls.set_margin_top(6)
        self.shuffle = Gtk.ToggleButton(icon_name="triat-shuffle-symbolic")
        self.shuffle.add_css_class("flat")
        self.shuffle.add_css_class("circular")
        self.shuffle.set_tooltip_text("Lecture aléatoire")
        self.shuffle.update_property(
            [Gtk.AccessibleProperty.LABEL], ["Lecture aléatoire"])
        controls.set_start_widget(self.shuffle)

        centre = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10,
                         halign=Gtk.Align.CENTER)
        self.prev_button = self._icon("triat-previous-symbolic", "Précédent", 40)
        self.play_button = self._icon("triat-play-symbolic", "Lecture", 52,
                                      primary=True)
        self.next_button = self._icon("triat-next-symbolic", "Suivant", 40)
        for widget in (self.prev_button, self.play_button, self.next_button):
            centre.append(widget)
        controls.set_center_widget(centre)

        right = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8,
                        valign=Gtk.Align.CENTER)
        self.repeat = Gtk.Button(icon_name="triat-repeat-symbolic")
        self.repeat.add_css_class("flat")
        self.repeat.add_css_class("circular")
        self.repeat.set_tooltip_text("Répétition : désactivée")
        self.repeat.update_property([Gtk.AccessibleProperty.LABEL], ["Répétition"])
        right.append(self.repeat)
        self.volume = DotVolume()
        right.append(self.volume)
        controls.set_end_widget(right)
        column.append(controls)
        return column

    def _build_tabs(self) -> Gtk.Widget:
        """À suivre / Paroles, en onglets."""
        column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12,
                         hexpand=True, vexpand=True)
        self._tabs_column = column
        chips = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.queue_chip = self._tab("À suivre")
        self.lyrics_chip = self._tab("Paroles")
        self.lyrics_chip.set_group(self.queue_chip)
        self.queue_chip.set_active(True)
        chips.append(self.queue_chip)
        chips.append(self.lyrics_chip)
        column.append(chips)

        self._tab_stack = Gtk.Stack(vexpand=True)
        self._tab_stack.set_transition_type(Gtk.StackTransitionType.NONE)

        self.queue_list = TrackList()
        self.queue_list.connect("track-activated", self._on_queue_activated)
        self.queue_list.connect("track-action", self._on_queue_action)
        scroller = Gtk.ScrolledWindow(vexpand=True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_child(self.queue_list)
        self.queue_column = scroller
        self._tab_stack.add_named(scroller, "queue")

        self.lyrics = LyricsView(self._engine)
        self.lyrics.header.set_visible(False)
        self.lyrics_column = self.lyrics
        self._tab_stack.add_named(self.lyrics, "lyrics")
        column.append(self._tab_stack)

        self.queue_chip.connect("toggled", lambda b: b.get_active()
                                and self._tab_stack.set_visible_child_name("queue"))
        self.lyrics_chip.connect("toggled", lambda b: b.get_active()
                                 and self._tab_stack.set_visible_child_name("lyrics"))
        return column

    @staticmethod
    def _tab(text: str) -> Gtk.ToggleButton:
        button = Gtk.ToggleButton()
        button.add_css_class("triat-chip")
        inner = Gtk.Box(spacing=7)
        inner.append(Gtk.Box(css_classes=["triat-chip-dot"], valign=Gtk.Align.CENTER))
        inner.append(Gtk.Label(label=text))
        button.set_child(inner)
        button.update_property([Gtk.AccessibleProperty.LABEL], [text])
        return button

    @staticmethod
    def _icon(name: str, tooltip: str, size: int,
              primary: bool = False) -> Gtk.Button:
        button = Gtk.Button(icon_name=name)
        button.add_css_class("circular")
        button.add_css_class("suggested-action" if primary else "flat")
        button.set_size_request(size, size)
        button.set_valign(Gtk.Align.CENTER)
        button.set_tooltip_text(tooltip)
        button.update_property([Gtk.AccessibleProperty.LABEL], [tooltip])
        return button

    # ---- Câblage ---------------------------------------------------------

    def _connect(self, engine) -> None:
        self.play_button.connect("clicked", lambda *_: engine.toggle_pause())
        self.next_button.connect("clicked", lambda *_: engine.next())
        self.prev_button.connect("clicked", lambda *_: engine.previous())
        self.progress.connect("seek-requested",
                              lambda _w, value: engine.seek(value))
        self.volume.connect("volume-changed",
                            lambda _w, value: engine.set_volume(value))
        self.volume.props.volume = float(engine.settings.get("volume"))

        self.shuffle.set_active(engine.shuffle)
        self.shuffle.connect(
            "toggled", lambda button: setattr(engine, "shuffle", button.get_active()))
        self.repeat.connect("clicked", self._cycle_repeat)
        self._show_repeat()

        self.radio_switch.set_active(bool(engine.settings.get("autoplay_radio")))
        self.radio_switch.connect(
            "toggled", lambda b: self._on_radio_toggled(b, b.get_active()))

        engine.connect("track-changed", self._on_track)
        engine.connect("state-changed", self._on_state)
        engine.connect("position-changed", self._on_position)
        engine.connect("duration-changed", self._on_duration)
        engine.connect("queue-changed", lambda *_: self._refresh_queue())
        self._refresh_queue()

    def _cycle_repeat(self, _button) -> None:
        order = ("off", "all", "one")
        current = self._engine.repeat
        self._engine.repeat = order[(order.index(current) + 1) % len(order)]
        self._show_repeat()

    def _show_repeat(self) -> None:
        libelle = {"off": "désactivée", "all": "la file", "one": "la piste"}
        mode = self._engine.repeat
        self.repeat.set_tooltip_text(f"Répétition : {libelle[mode]}")
        self.repeat.set_icon_name(
            "triat-repeat-one-symbolic" if mode == "one"
            else "triat-repeat-symbolic")
        if mode == "off":
            self.repeat.remove_css_class("triat-accent-text")
        else:
            self.repeat.add_css_class("triat-accent-text")

    def _on_radio_toggled(self, _switch, state: bool) -> bool:
        self._engine.settings.set("autoplay_radio", state)
        self._engine.settings.save()
        return False

    def _open_artist(self, _button) -> None:
        ref = self._engine.current
        if self._on_artist is not None and ref is not None:
            self._on_artist(ref.artist or "")

    def _on_favorite(self, button) -> None:
        if self._engine.current is None:
            return
        added = self._engine.toggle_favorite()
        self._show_favorite(added)

    def _show_favorite(self, favorite: bool) -> None:
        self.favorite.handler_block(self._favorite_handler)
        self.favorite.set_active(favorite)
        self.favorite.handler_unblock(self._favorite_handler)
        self.favorite.set_tooltip_text(
            "Retirer des favoris" if favorite else "Ajouter aux favoris")
        if favorite:
            self.favorite.add_css_class("triat-accent-text")
        else:
            self.favorite.remove_css_class("triat-accent-text")

    def _on_queue_activated(self, _list, position: int) -> None:
        self._engine.jump_to(position)

    def _on_queue_action(self, _list, action: str, position: int) -> None:
        refs = self._engine.queue.items
        if not (0 <= position < len(refs)):
            return
        from .track_actions import TrackActions

        TrackActions(self._engine, parent=self).handle(action, refs[position])

    # ---- Réactions -------------------------------------------------------

    def _on_track(self, _engine, ref) -> None:
        if ref is None:
            self._title.set_text("Rien en lecture")
            self._artist.set_text("")
            self.disc.set_seed(7)
            self.progress.clear()
            return
        self._title.set_text(ref.title)
        self._artist.set_text(ref.artist or "")
        self.disc.set_track(ref)
        self.progress.props.duration = ref.duration or 0.0
        self._total.set_text(format_time(ref.duration))
        self.queue_list.set_current(ref.video_id)
        try:
            favori = bool(self._engine.is_favorite())
        except Exception:
            favori = False
        self._show_favorite(favori)

    def _on_state(self, _engine, state: str) -> None:
        playing = state == "playing"
        self.play_button.set_icon_name(
            "triat-pause-symbolic" if playing
            else "triat-play-symbolic")
        self.play_button.set_sensitive(state != "idle")

    def _on_position(self, _engine, value: float) -> None:
        self.progress.props.position = value
        self._elapsed.set_text(format_time(value))

    def _on_duration(self, _engine, value: float) -> None:
        if value > 0:
            self.progress.props.duration = value
            self._total.set_text(format_time(value))

    def _refresh_queue(self) -> None:
        self.queue_list.set_tracks(self._engine.queue.items)
        current = self._engine.current
        self.queue_list.set_current(current.video_id if current else None)
        self.next_button.set_sensitive(self._engine.queue.has_next)
        self.prev_button.set_sensitive(self._engine.queue.has_previous
                                       or current is not None)

    def set_narrow(self, narrow: bool) -> None:
        """Fenêtre étroite : les onglets passent sous le lecteur."""
        self._body.set_orientation(Gtk.Orientation.VERTICAL if narrow
                                   else Gtk.Orientation.HORIZONTAL)
        size = ART_SIZE if narrow else ART_SIZE_WIDE
        self.disc.set_size_request(size, size)
        self._player_column.set_size_request(-1 if narrow else 560, -1)
        self._body.set_spacing(18 if narrow else 36)

    def set_segments(self, segments) -> None:
        self.progress.set_segments([(s.start, s.end, 1.0) for s in segments])

"""Écran Immersion : le clip en grand, contrôles par-dessus (screens.md §6).

Même instance mpv que la lecture audio : entrer ou sortir n'interrompt
jamais le son, on greffe ou retire seulement la piste d'image.
"""

from __future__ import annotations

import logging
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Gdk, GLib, Gtk

from ..core.spectrum import Spectrum

from .widgets.cover import Cover
from .widgets.dot_progress import DotProgressBar
from .widgets.dot_volume import DotVolume
from .widgets.glyph import GlyphArt
from .widgets.video_area import VideoArea

log = logging.getLogger(__name__)

# Délai sans mouvement avant de masquer les contrôles (GTK.md §6).
HIDE_AFTER_MS = 3000
# Points par côté de la matrice plein écran : assez pour reconnaître une
# pochette, assez peu pour que chaque point reste un point.
GLYPH_GRID = 48
# Durée d'affichage du rappel « Bouger la souris… ».
HINT_MS = 2200

VIDEO_MESSAGES = {
    "loading": "Chargement du clip…",
    "unavailable": "Clip indisponible — la musique continue",
    "no-gl": "Rendu vidéo impossible sur cet affichage",
}


def _format_time(seconds: float) -> str:
    seconds = max(0, int(seconds or 0))
    return f"{seconds // 60}:{seconds % 60:02d}"


def _label(text: str, *css: str, **kwargs) -> Gtk.Label:
    label = Gtk.Label(label=text, **kwargs)
    for name in css:
        label.add_css_class(name)
    return label


class ImmersionView(Gtk.Overlay):
    def __init__(self, engine, on_close, on_fullscreen=None) -> None:
        super().__init__(focusable=True)
        self.add_css_class("triat-immersion")
        self._engine = engine
        self._on_close = on_close
        self._on_fullscreen = on_fullscreen or (lambda: None)
        self._area: VideoArea | None = None
        self._active = False
        self._hide_source = 0
        self._hint_source = 0
        self._last_pointer: tuple[float, float] | None = None
        self._lyrics = None
        self._lyrics_token = 0
        self._lyric_index = -2
        self._handlers: list[int] = []
        self._mode = engine.settings.get("immersion_mode") or "clip"
        self._syncing_chips = False
        self._spectrum = Spectrum()

        self._build()
        self._install_controllers()

    # ---- Construction ----------------------------------------------------

    def _build(self) -> None:
        # Deux scènes plein écran : le clip dans un cadre 16:9, ou la
        # pochette tramée en matrice de points qui bat avec la musique.
        # La surface vidéo reste toujours affichée : une GLArea réalisée
        # hors écran ne reçoit plus d'images de mpv (constaté le 23/09).
        # La matrice se pose donc par-dessus, en calque opaque.
        self.field = Gtk.Overlay(hexpand=True, vexpand=True)
        self.set_child(self.field)
        self._scene = "clip"

        self.frame = Gtk.AspectFrame(ratio=16 / 9, obey_child=False,
                                     hexpand=True, vexpand=True)
        self.frame.set_margin_top(96)
        self.frame.set_margin_bottom(150)
        self.frame.set_margin_start(48)
        self.frame.set_margin_end(48)
        self.screen = Gtk.Overlay()
        self.screen.add_css_class("triat-video-frame")
        self.screen.set_overflow(Gtk.Overflow.HIDDEN)
        self.frame.set_child(self.screen)
        self.field.set_child(self.frame)

        self.glyph = GlyphArt(grid=GLYPH_GRID, size=640, radius=0.0)
        self.glyph.set_hexpand(True)
        self.glyph.set_vexpand(True)
        self.glyph.set_margin_top(110)
        self.glyph.set_margin_bottom(170)
        self.glyph.set_can_target(False)
        self.glyph_layer = Gtk.Box(hexpand=True, vexpand=True)
        self.glyph_layer.add_css_class("triat-glyph-layer")
        self.glyph_layer.append(self.glyph)
        self.glyph_layer.set_can_target(False)
        self.field.add_overlay(self.glyph_layer)

        # Repli tant que l'image n'est pas là : pochette + message.
        self.placeholder = Gtk.Box(orientation=Gtk.Orientation.VERTICAL,
                                   spacing=16, halign=Gtk.Align.CENTER,
                                   valign=Gtk.Align.CENTER)
        self.cover = Cover(size=160, radius=12.0)
        self.placeholder.append(self.cover)
        self.message = _label("", "triat-mono")
        self.placeholder.append(self.message)
        self.placeholder_box = Gtk.Box(hexpand=True, vexpand=True)
        self.placeholder_box.add_css_class("triat-video-placeholder")
        self.placeholder_box.append(self.placeholder)
        self.placeholder.set_hexpand(True)
        self.screen.set_child(self.placeholder_box)

        self.add_overlay(self._build_top())
        self.add_overlay(self._build_subtitles())
        self.add_overlay(self._build_bottom())

        self.hint = _label("Bouger la souris pour les contrôles",
                           "triat-mono", "triat-immersion-hint",
                           valign=Gtk.Align.END, halign=Gtk.Align.CENTER,
                           margin_bottom=28)
        self.hint.set_can_target(False)
        self.hint.set_opacity(0.0)
        self.add_overlay(self.hint)
        self._show_line(None, None)

    def _build_top(self) -> Gtk.Widget:
        top = Gtk.CenterBox(valign=Gtk.Align.START)
        top.add_css_class("triat-immersion-top")
        top.set_margin_top(24)
        top.set_margin_start(48)
        top.set_margin_end(48)

        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        badge = Gtk.Box(spacing=8)
        dot = Gtk.Box(valign=Gtk.Align.CENTER)
        dot.add_css_class("triat-accent-dot")
        badge.append(dot)
        badge.append(_label("Plein écran", "triat-label"))
        left.append(badge)
        self.title = _label("", "triat-display", "immersion-title",
                            xalign=0, ellipsize=3, max_width_chars=48)
        left.append(self.title)
        self.artist = _label("", "triat-body", "triat-dim", xalign=0)
        left.append(self.artist)
        top.set_start_widget(left)

        right = Gtk.Box(spacing=12, valign=Gtk.Align.START)
        self.format_pill = _label("", "triat-mono", "triat-pill")
        self.format_pill.set_visible(False)
        right.append(self.format_pill)
        quit_button = Gtk.Button(label="Quitter (Échap)")
        quit_button.add_css_class("triat-pill-button")
        quit_button.connect("clicked", lambda *_: self._on_close())
        right.append(quit_button)
        top.set_end_widget(right)
        self.top = top
        return top

    def _build_subtitles(self) -> Gtk.Widget:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8,
                      halign=Gtk.Align.CENTER, valign=Gtk.Align.END)
        box.set_margin_bottom(176)
        box.set_can_target(False)
        self.previous_line = _label("", "triat-immersion-prev",
                                    wrap=True, justify=Gtk.Justification.CENTER)
        box.append(self.previous_line)
        self.current_pill = Gtk.Box(spacing=12, halign=Gtk.Align.CENTER)
        self.current_pill.add_css_class("triat-immersion-line")
        dot = Gtk.Box(valign=Gtk.Align.CENTER)
        dot.add_css_class("triat-accent-dot")
        dot.add_css_class("lg")
        self.current_pill.append(dot)
        self.current_line = _label("", wrap=True, max_width_chars=60,
                                   justify=Gtk.Justification.CENTER)
        self.current_pill.append(self.current_line)
        box.append(self.current_pill)
        self.subtitles = box
        return box

    def _build_bottom(self) -> Gtk.Widget:
        bottom = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10,
                         valign=Gtk.Align.END)
        bottom.add_css_class("triat-immersion-bottom")
        bottom.set_margin_start(48)
        bottom.set_margin_end(48)
        bottom.set_margin_bottom(24)

        self.progress = DotProgressBar(step=8.0, radius=1.7, height=12)
        self.elapsed = _label("0:00", "triat-mono", "triat-dim")
        self.total = _label("0:00", "triat-mono", "triat-dim")
        seek = Gtk.Box(spacing=12)
        seek.append(self.elapsed)
        seek.append(self.progress)
        seek.append(self.total)
        bottom.append(seek)

        controls = Gtk.CenterBox()
        chips = Gtk.Box(spacing=8, valign=Gtk.Align.CENTER)
        self.clip_chip = Gtk.ToggleButton(label="Clip")
        self.glyph_chip = Gtk.ToggleButton(label="Matrice", group=self.clip_chip)
        self.lyrics_chip = Gtk.ToggleButton(label="Paroles", active=True)
        for chip in (self.clip_chip, self.glyph_chip, self.lyrics_chip):
            chip.add_css_class("triat-chip")
            chips.append(chip)
        self.clip_chip.set_tooltip_text("Le clip officiel (V pour basculer)")
        self.glyph_chip.set_tooltip_text(
            "La pochette en matrice de points, au rythme du son (V)")
        self.clip_chip.connect("toggled", self._on_mode_chip, "clip")
        self.glyph_chip.connect("toggled", self._on_mode_chip, "glyph")
        self.lyrics_chip.connect("toggled", lambda b: self.subtitles.set_visible(
            b.get_active() and self._has_lyric_line()))
        controls.set_start_widget(chips)

        centre = Gtk.Box(spacing=14, halign=Gtk.Align.CENTER)
        self.prev_button = self._icon("triat-previous-symbolic", "Précédent", 44)
        self.play_button = self._icon("triat-play-symbolic", "Lecture", 56, True)
        self.next_button = self._icon("triat-next-symbolic", "Suivant", 44)
        for button in (self.prev_button, self.play_button, self.next_button):
            centre.append(button)
        controls.set_center_widget(centre)

        right = Gtk.Box(spacing=16, valign=Gtk.Align.CENTER)
        self.up_next = _label("", "triat-mono", "triat-dim",
                              ellipsize=3, max_width_chars=32)
        right.append(self.up_next)
        self.volume = DotVolume()
        right.append(self.volume)
        controls.set_end_widget(right)
        bottom.append(controls)
        self.bottom = bottom
        return bottom

    @staticmethod
    def _icon(name: str, tooltip: str, size: int,
              primary: bool = False) -> Gtk.Button:
        button = Gtk.Button(icon_name=name)
        button.add_css_class("circular")
        button.add_css_class("suggested-action" if primary else "flat")
        button.set_size_request(size, size)
        button.set_tooltip_text(tooltip)
        button.update_property([Gtk.AccessibleProperty.LABEL], [tooltip])
        return button

    def _install_controllers(self) -> None:
        motion = Gtk.EventControllerMotion()
        motion.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        motion.connect("motion", self._on_motion)
        self.add_controller(motion)

        click = Gtk.GestureClick()
        click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        click.connect("pressed", lambda *_: self._reveal())
        self.add_controller(click)

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        engine = self._engine
        self.play_button.connect("clicked", lambda *_: engine.toggle_pause())
        self.next_button.connect("clicked", lambda *_: engine.next())
        self.prev_button.connect("clicked", lambda *_: engine.previous())
        self.progress.connect("seek-requested", lambda _w, v: engine.seek(v))
        self.volume.connect("volume-changed", lambda _w, v: engine.set_volume(v))

    # ---- Entrée / sortie ---------------------------------------------------

    @property
    def active(self) -> bool:
        return self._active

    def activate(self) -> None:
        """Appelé à l'affichage : branche le moteur et crée la surface GL."""
        if self._active:
            return
        self._active = True
        engine = self._engine
        for signal, handler in (
                ("track-changed", self._on_track),
                ("state-changed", self._on_state),
                ("position-changed", self._on_position),
                ("duration-changed", self._on_duration),
                ("queue-changed", lambda *_: self._refresh_up_next()),
                ("video-changed", self._on_video)):
            self._handlers.append(engine.connect(signal, handler))
        self.volume.props.volume = float(engine.settings.get("volume"))
        self._on_track(engine, engine.current)
        self._on_state(engine, engine.player.state)
        self._on_duration(engine, engine.player.duration)
        self._on_position(engine, engine.player.position_hint)
        self._refresh_up_next()

        # Le contexte de rendu doit exister avant que mpv n'ouvre la piste
        # vidéo : sinon sa sortie échoue et il désactive l'image pour de bon.
        self._area = VideoArea(engine.player)
        self._area.connect("realize", self._on_area_realized)
        self._area.set_opacity(0.0)
        self.screen.add_overlay(self._area)
        self._set_message("loading")
        # Matrice d'abord : elle est prête tout de suite, le clip la
        # remplace dès qu'il arrive.
        self._show_scene("glyph" if self._mode == "glyph" else "clip")
        self.set_mode(self._mode, remember=False)
        self._reveal()
        self.grab_focus()

    def deactivate(self) -> None:
        if not self._active:
            return
        self._active = False
        self._spectrum.stop()
        self._engine.set_video_mode(False)
        for handler in self._handlers:
            self._engine.disconnect(handler)
        self._handlers.clear()
        if self._area is not None:
            # Le retrait déclenche `unrealize`, qui libère le rendu mpv
            # avec le contexte GL courant.
            self.screen.remove_overlay(self._area)
            self._area = None
        for source in (self._hide_source, self._hint_source):
            if source:
                GLib.source_remove(source)
        self._hide_source = self._hint_source = 0
        self.set_cursor(None)

    def _on_area_realized(self, area) -> None:
        # Après le gestionnaire interne de VideoArea, connecté en premier.
        if not area.ready:
            self._set_message("no-gl")
            self._show_scene("glyph")
            return
        if self._mode == "clip":
            self._engine.set_video_mode(True)

    # ---- Moteur --------------------------------------------------------------

    def _on_track(self, _engine, ref) -> None:
        self.title.set_text(ref.title if ref else "")
        self.artist.set_text((ref.artist or "") if ref else "")
        self.cover.set_track(ref)
        self.glyph.set_track(ref)
        self.format_pill.set_visible(False)
        self._load_lyrics(ref)

    def _on_state(self, _engine, state: str) -> None:
        playing = state == "playing"
        self.play_button.set_icon_name(
            "triat-pause-symbolic" if playing else "triat-play-symbolic")
        self.play_button.set_tooltip_text("Pause" if playing else "Lecture")

    def _on_position(self, _engine, value: float) -> None:
        self.progress.props.position = value
        self.elapsed.set_text(_format_time(value))
        self._update_lyric(value)

    def _on_duration(self, _engine, value: float) -> None:
        if value > 0:
            self.progress.props.duration = value
            self.total.set_text(_format_time(value))

    def _on_video(self, _engine, state: str, stream) -> None:
        if state in ("unavailable", "no-gl") and self._mode == "clip":
            # Pas de clip pour ce titre : la matrice prend le relais, et on
            # retentera le clip au titre suivant.
            self._show_scene("glyph")
        if state == "ready" and self._mode == "clip":
            self._show_scene("clip")
        if state == "ready":
            if self._area is not None:
                self._area.set_opacity(1.0)
            self.placeholder_box.set_visible(False)
            if stream is not None and stream.label:
                self.format_pill.set_text(f"{stream.label} · Opus")
                self.format_pill.set_visible(True)
        elif state in VIDEO_MESSAGES:
            self._set_message(state)

    def _set_message(self, state: str) -> None:
        # Opacité plutôt que visibilité : masquer la surface GL pendant sa
        # réalisation fait râler GTK (« snapshot without allocation »).
        if self._area is not None:
            self._area.set_opacity(0.0)
        self.placeholder_box.set_visible(True)
        self.message.set_text(VIDEO_MESSAGES.get(state, ""))

    def _refresh_up_next(self) -> None:
        upcoming = self._engine.queue.upcoming
        self.up_next.set_text(f"À suivre : {upcoming[0].title}" if upcoming
                              else "")

    # ---- Paroles en sous-titres ------------------------------------------------

    def _load_lyrics(self, ref) -> None:
        self._lyrics_token += 1
        token = self._lyrics_token
        self._lyrics = None
        self._lyric_index = -2
        self._show_line(None, None)
        if ref is None:
            return

        def worker() -> None:
            try:
                lyrics = self._engine.lyrics.fetch(ref)
            except Exception as exc:
                log.debug("Paroles indisponibles : %s", exc)
                return
            GLib.idle_add(self._lyrics_ready, lyrics, token)

        threading.Thread(target=worker, daemon=True).start()

    def _lyrics_ready(self, lyrics, token: int) -> bool:
        if token == self._lyrics_token and lyrics.lines:
            self._lyrics = lyrics
            self._update_lyric(self._engine.player.position_hint)
        return GLib.SOURCE_REMOVE

    def _update_lyric(self, position: float) -> None:
        if self._lyrics is None:
            return
        index = self._lyrics.index_at(position)
        if index == self._lyric_index:
            return
        self._lyric_index = index
        lines = self._lyrics.lines
        current = lines[index][1] if index >= 0 else None
        previous = lines[index - 1][1] if index >= 1 else None
        self._show_line(previous, current)

    def _show_line(self, previous: str | None, current: str | None) -> None:
        self.previous_line.set_text(previous or "")
        self.previous_line.set_visible(bool(previous))
        self.current_line.set_text(current or "")
        self.subtitles.set_visible(bool(current)
                                   and self.lyrics_chip.get_active())

    def _has_lyric_line(self) -> bool:
        return bool(self.current_line.get_text())

    # ---- Contrôles masqués -------------------------------------------------

    def _on_motion(self, _controller, x: float, y: float) -> None:
        # Hyprland envoie un « mouvement » à l'entrée du pointeur et à chaque
        # changement de focus : on ne réagit qu'à un vrai déplacement.
        if self._last_pointer is not None:
            dx = abs(x - self._last_pointer[0])
            dy = abs(y - self._last_pointer[1])
            if dx < 2 and dy < 2:
                return
        self._last_pointer = (x, y)
        self._reveal()

    def _reveal(self) -> None:
        for widget in (self.top, self.bottom):
            widget.remove_css_class("triat-concealed")
            widget.set_can_target(True)
        self.set_cursor(None)
        self._fade_hint(False)
        if self._hide_source:
            GLib.source_remove(self._hide_source)
        self._hide_source = GLib.timeout_add(HIDE_AFTER_MS, self._conceal)

    def _conceal(self) -> bool:
        self._hide_source = 0
        if not self._active:
            return GLib.SOURCE_REMOVE
        for widget in (self.top, self.bottom):
            widget.add_css_class("triat-concealed")
            widget.set_can_target(False)
        self.set_cursor(Gdk.Cursor.new_from_name("none"))
        self._fade_hint(True)
        return GLib.SOURCE_REMOVE

    @property
    def controls_visible(self) -> bool:
        return not self.bottom.has_css_class("triat-concealed")

    def _fade_hint(self, show: bool) -> None:
        if self._hint_source:
            GLib.source_remove(self._hint_source)
            self._hint_source = 0
        self.hint.set_opacity(1.0 if show else 0.0)
        if show:
            def hide() -> bool:
                self._hint_source = 0
                self.hint.set_opacity(0.0)
                return GLib.SOURCE_REMOVE
            self._hint_source = GLib.timeout_add(HINT_MS, hide)

    # ---- Clavier ---------------------------------------------------------------

    def _on_key(self, _controller, keyval: int, _code: int, state) -> bool:
        if state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK):
            return False
        if keyval == Gdk.KEY_Escape:
            self._on_close()
            return True
        if keyval in (Gdk.KEY_f, Gdk.KEY_F):
            self._on_fullscreen()
            return True
        if keyval in (Gdk.KEY_v, Gdk.KEY_V):
            self.set_mode("glyph" if self._mode == "clip" else "clip")
            self._reveal()
            return True
        if keyval in (Gdk.KEY_l, Gdk.KEY_L):
            self.lyrics_chip.set_active(not self.lyrics_chip.get_active())
            self._reveal()
            return True
        if keyval == Gdk.KEY_Left:
            self._engine.seek(max(0.0, self._engine.player.position_hint - 5))
            return True
        if keyval == Gdk.KEY_Right:
            self._engine.seek(self._engine.player.position_hint + 5)
            return True
        return False

    # ---- Scènes : clip ou matrice -----------------------------------------

    @property
    def mode(self) -> str:
        """Préférence de l'utilisateur, pas forcément la scène affichée."""
        return self._mode

    @property
    def scene(self) -> str:
        return self._scene

    def set_mode(self, mode: str, remember: bool = True) -> None:
        self._mode = mode
        if remember:
            self._engine.settings.set("immersion_mode", mode)
            self._engine.settings.save()
        self._syncing_chips = True
        try:
            (self.clip_chip if mode == "clip" else self.glyph_chip).set_active(True)
        finally:
            self._syncing_chips = False
        if not self._active:
            return
        if mode == "clip" and self._area is not None and self._area.ready:
            self._engine.set_video_mode(True)
            if self._engine.video_state != "ready":
                # Le clip arrive : on garde la matrice en attendant.
                self._show_scene("glyph" if self.scene == "glyph" else "clip")
            else:
                self._show_scene("clip")
        else:
            self._engine.set_video_mode(False)
            self._show_scene("glyph")

    def _on_mode_chip(self, button, mode: str) -> None:
        if button.get_active() and not self._syncing_chips:
            self.set_mode(mode)
            self._reveal()

    def _show_scene(self, scene: str) -> None:
        self._scene = scene
        if scene == "glyph":
            self.glyph_layer.remove_css_class("triat-hidden-layer")
        else:
            self.glyph_layer.add_css_class("triat-hidden-layer")
        if scene == "glyph" and self._active:
            if not self._spectrum.running:
                self._spectrum.start(self.glyph.set_levels)
        else:
            self._spectrum.stop()
            self.glyph.set_levels([])

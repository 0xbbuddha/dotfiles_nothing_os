"""Mini-lecteur (screens.md §7).

Fenêtre sans décoration, 440×168, déplaçable à la souris. Sous Wayland une
application ne peut pas se placer au-dessus des autres : c'est la règle
Hyprland `triat-mini` qui l'épingle (GTK.md §7).
"""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gtk

from .track_list import format_time
from .widgets.cover import Cover
from .widgets.dot_progress import DotProgressBar

WIDTH = 440
HEIGHT = 168
COVER = 108


def _label(text: str, *css: str, **kwargs) -> Gtk.Label:
    widget = Gtk.Label(label=text, xalign=0, **kwargs)
    for name in css:
        widget.add_css_class(name)
    return widget


class MiniPlayer(Adw.ApplicationWindow):
    """Télécommande compacte."""

    def __init__(self, app, engine, on_expand=None) -> None:
        super().__init__(application=app, title="Triat — mini")
        self._engine = engine
        self._on_expand = on_expand

        self.set_default_size(WIDTH, HEIGHT)
        self.set_resizable(False)
        self.set_decorated(False)
        self.add_css_class("triat-mini")

        cover = Cover(size=COVER, radius=14.0)
        self.cover = cover

        self._title = _label("Rien en lecture", "triat-display", "xs")
        self._title.set_ellipsize(3)
        self._title.set_max_width_chars(18)
        self._artist = _label("", "triat-body", "triat-dim")
        self._artist.set_ellipsize(3)
        self._artist.set_max_width_chars(22)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2,
                        hexpand=True, valign=Gtk.Align.START)
        texts.append(self._title)
        texts.append(self._artist)
        top.append(texts)

        expand = Gtk.Button(icon_name="triat-chevron-down-symbolic")
        expand.add_css_class("flat")
        expand.add_css_class("circular")
        expand.set_size_request(32, 32)
        expand.set_valign(Gtk.Align.START)
        expand.set_tooltip_text("Ouvrir la fenêtre principale")
        expand.update_property([Gtk.AccessibleProperty.LABEL],
                               ["Ouvrir la fenêtre principale"])
        expand.connect("clicked", self._expand)
        top.append(expand)

        self.progress = DotProgressBar(step=5.0, radius=1.3, height=8,
                                       show_head=False)
        self._elapsed = _label("0:00", "triat-mono", "triat-dim")

        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        self.prev_button = self._icon("triat-previous-symbolic", "Précédent", 32)
        self.play_button = self._icon("triat-play-symbolic", "Lecture", 36, True)
        self.next_button = self._icon("triat-next-symbolic", "Suivant", 32)
        controls.append(self.prev_button)
        controls.append(self.play_button)
        controls.append(self.next_button)
        controls.append(Gtk.Box(hexpand=True))
        controls.append(self._elapsed)

        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6,
                        hexpand=True)
        right.append(top)
        spacer = Gtk.Box(vexpand=True)
        spacer.set_size_request(-1, 0)
        right.append(spacer)
        right.append(self.progress)
        right.append(controls)

        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        body.set_margin_start(12)
        body.set_margin_end(12)
        body.set_margin_top(12)
        body.set_margin_bottom(12)
        body.append(cover)
        body.append(right)

        # Sans décoration, c'est la poignée qui rend la fenêtre déplaçable.
        handle = Gtk.WindowHandle()
        handle.set_child(body)
        self.set_content(handle)

        self._connect()
        self._install_shortcuts()

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

    # ---- Câblage ---------------------------------------------------------

    def _connect(self) -> None:
        engine = self._engine
        self.play_button.connect("clicked", lambda *_: engine.toggle_pause())
        self.next_button.connect("clicked", lambda *_: engine.next())
        self.prev_button.connect("clicked", lambda *_: engine.previous())
        self.progress.connect("seek-requested",
                              lambda _w, value: engine.seek(value))

        engine.connect("track-changed", self._on_track)
        engine.connect("state-changed", self._on_state)
        engine.connect("position-changed", self._on_position)
        engine.connect("duration-changed", self._on_duration)
        if engine.current is not None:
            self._on_track(engine, engine.current)

    def _install_shortcuts(self) -> None:
        controller = Gtk.ShortcutController()
        controller.set_scope(Gtk.ShortcutScope.GLOBAL)

        def add(accel: str, callback) -> None:
            controller.add_shortcut(Gtk.Shortcut(
                trigger=Gtk.ShortcutTrigger.parse_string(accel),
                action=Gtk.CallbackAction.new(callback)))

        add("space", lambda *_: (self._engine.toggle_pause(), True)[1])
        add("Escape", lambda *_: (self.close(), True)[1])
        self.add_controller(controller)

    def _expand(self, _button) -> None:
        if self._on_expand is not None:
            self._on_expand()
        self.close()

    # ---- Réactions -------------------------------------------------------

    def _on_track(self, _engine, ref) -> None:
        if ref is None:
            self._title.set_text("Rien en lecture")
            self._artist.set_text("")
            self.cover.clear()
            self.progress.clear()
            return
        self._title.set_text(ref.title)
        self._artist.set_text(ref.artist or "")
        self.cover.set_track(ref)
        self.progress.props.duration = ref.duration or 0.0

    def _on_state(self, _engine, state: str) -> None:
        playing = state == "playing"
        self.play_button.set_icon_name(
            "triat-pause-symbolic" if playing else "triat-play-symbolic")
        self.play_button.set_sensitive(state != "idle")

    def _on_position(self, _engine, value: float) -> None:
        self.progress.props.position = value
        self._elapsed.set_text(format_time(value))

    def _on_duration(self, _engine, value: float) -> None:
        if value > 0:
            self.progress.props.duration = value

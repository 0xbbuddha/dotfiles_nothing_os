"""DotVolume — volume en points (DESIGN.md §5).

Même motif que la progression : les points allumés donnent le niveau, le
reste reste visible à faible opacité.
"""

from __future__ import annotations

from gi.repository import Gdk, GObject, Graphene, Gsk, Gtk

from .dot_progress import rgba

DOT_ON = "#f1f1f1"
DOT_OFF_ALPHA = 0.25
STEP_KEY = 5.0


class DotVolume(Gtk.Widget):
    """Volume 0-100. Émet `volume-changed`."""

    __gtype_name__ = "TriatDotVolume"

    __gsignals__ = {
        "volume-changed": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
    }

    volume = GObject.Property(type=float, default=85.0)

    def __init__(self, step: float = 7.0, radius: float = 1.6,
                 dots: int = 12) -> None:
        super().__init__(focusable=True, can_focus=True,
                         accessible_role=Gtk.AccessibleRole.SLIDER)
        self.step = step
        self.radius = radius
        self.dots = dots
        self.add_css_class("triat-volume")
        self.set_size_request(int(step * dots), 16)
        self.set_valign(Gtk.Align.CENTER)
        self.connect("notify::volume", lambda *_: self.queue_draw())

        click = Gtk.GestureClick()
        click.connect("pressed", self._on_pressed)
        self.add_controller(click)

        drag = Gtk.GestureDrag()
        drag.connect("drag-update", self._on_drag)
        self.add_controller(drag)

        scroll = Gtk.EventControllerScroll(
            flags=Gtk.EventControllerScrollFlags.VERTICAL)
        scroll.connect("scroll", self._on_scroll)
        self.add_controller(scroll)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        self.update_property([Gtk.AccessibleProperty.LABEL], ["Volume"])

    # ---- Rendu -----------------------------------------------------------

    def do_snapshot(self, snapshot: Gtk.Snapshot) -> None:
        width, height = self.get_width(), self.get_height()
        if width <= 0:
            return
        level = min(max(self.props.volume, 0.0), 100.0) / 100.0
        lit = round(level * self.dots)
        centre_y = height / 2
        for index in range(self.dots):
            x = index * self.step + self.step / 2
            colour = rgba(DOT_ON) if index < lit else rgba(DOT_ON, DOT_OFF_ALPHA)
            rect = Graphene.Rect().init(x - self.radius, centre_y - self.radius,
                                        self.radius * 2, self.radius * 2)
            rounded = Gsk.RoundedRect()
            rounded.init_from_rect(rect, self.radius)
            snapshot.push_rounded_clip(rounded)
            snapshot.append_color(colour, rect)
            snapshot.pop()

    def do_measure(self, orientation, _for_size):
        if orientation == Gtk.Orientation.VERTICAL:
            return (16, 16, -1, -1)
        size = int(self.step * self.dots)
        return (size, size, -1, -1)

    # ---- Interaction -----------------------------------------------------

    def _apply(self, value: float) -> None:
        value = min(max(value, 0.0), 100.0)
        if abs(value - self.props.volume) < 0.5:
            return
        self.props.volume = value
        self.emit("volume-changed", value)

    def _level_at(self, x: float) -> float:
        width = max(self.get_width(), 1)
        return min(max(x / width, 0.0), 1.0) * 100.0

    def _on_pressed(self, _gesture, _n, x: float, _y: float) -> None:
        self.grab_focus()
        self._apply(self._level_at(x))

    def _on_drag(self, gesture, offset_x: float, _offset_y: float) -> None:
        ok, start_x, _ = gesture.get_start_point()
        if ok:
            self._apply(self._level_at(start_x + offset_x))

    def _on_scroll(self, _controller, _dx: float, dy: float) -> bool:
        self._apply(self.props.volume - dy * STEP_KEY)
        return True

    def _on_key(self, _controller, keyval: int, _keycode: int,
                _state: Gdk.ModifierType) -> bool:
        if keyval in (Gdk.KEY_Left, Gdk.KEY_Down):
            self._apply(self.props.volume - STEP_KEY)
        elif keyval in (Gdk.KEY_Right, Gdk.KEY_Up):
            self._apply(self.props.volume + STEP_KEY)
        elif keyval == Gdk.KEY_Home:
            self._apply(0.0)
        elif keyval == Gdk.KEY_End:
            self._apply(100.0)
        else:
            return False
        return True

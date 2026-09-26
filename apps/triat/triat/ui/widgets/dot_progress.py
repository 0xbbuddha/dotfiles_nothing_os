"""DotProgressBar — progression en points, avec segments SponsorBlock.

Le motif de Triat : jamais de barre pleine, une rangée de points qui
s'allument un par un (DESIGN.md §5).
"""

from __future__ import annotations

from gi.repository import Gdk, GObject, Graphene, Gsk, Gtk

# Repères visuels de DESIGN.md §5. La couleur d'accent vient du CSS
# (`.triat-progress { color: var(--triat-accent); }`), pas d'une constante.
DOT_OFF = "#333333"
DOT_ON = "#f1f1f1"
HEAD_RING = "#0e0e0e"
HEAD_FILL = "#ffffff"

SEEK_KEY_STEP = 5.0


def rgba(spec: str, alpha: float = 1.0) -> Gdk.RGBA:
    color = Gdk.RGBA()
    color.parse(spec)
    color.alpha = alpha
    return color


class DotProgressBar(Gtk.Widget):
    """Rangée de points cliquable. Émet `seek-requested` avec une position en secondes."""

    __gtype_name__ = "TriatDotProgressBar"

    __gsignals__ = {
        "seek-requested": (GObject.SignalFlags.RUN_FIRST, None, (float,)),
    }

    position = GObject.Property(type=float, default=0.0)   # secondes
    duration = GObject.Property(type=float, default=0.0)   # secondes

    def __init__(self, step: float = 6.0, radius: float = 1.5,
                 height: int = 10, show_head: bool = True) -> None:
        super().__init__(focusable=True, can_focus=True,
                         accessible_role=Gtk.AccessibleRole.SLIDER)
        self.step = step
        self.radius = radius
        self.bar_height = height
        self.show_head = show_head
        # (début, fin, opacité) en secondes — segments SponsorBlock.
        self.segments: list[tuple[float, float, float]] = []
        self._dragging = False

        self.add_css_class("triat-progress")
        self.set_size_request(-1, max(height, 16))
        self.set_hexpand(True)

        # La position change 5 fois par seconde ; à 5 px le point, la barre
        # ne change visuellement qu'une fois toutes les quelques secondes.
        # On ne redessine que si le demi-pixel de la tête a bougé.
        self._drawn_key = None
        for prop in ("position", "duration"):
            self.connect(f"notify::{prop}", lambda *_: self._maybe_redraw())

        click = Gtk.GestureClick()
        click.connect("pressed", self._on_pressed)
        self.add_controller(click)

        drag = Gtk.GestureDrag()
        drag.connect("drag-begin", self._on_drag_begin)
        drag.connect("drag-update", self._on_drag_update)
        drag.connect("drag-end", self._on_drag_end)
        self.add_controller(drag)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        self._update_accessible()

    # ---- API ------------------------------------------------------------

    def set_segments(self, segments) -> None:
        """`segments` : itérable de (début, fin, opacité)."""
        self.segments = [(float(a), float(b), float(o)) for a, b, o in segments]
        self.queue_draw()

    def clear(self) -> None:
        self.segments = []
        self.props.position = 0.0
        self.props.duration = 0.0
        self.queue_draw()

    # ---- Rendu ----------------------------------------------------------

    def _maybe_redraw(self) -> None:
        duration = self.props.duration
        width = max(self.get_width(), 1)
        fraction = self.props.position / duration if duration > 0 else 0.0
        key = (round(fraction * width * 2), duration > 0)
        if key != self._drawn_key:
            self._drawn_key = key
            self.queue_draw()

    def do_snapshot(self, snapshot: Gtk.Snapshot) -> None:
        width = self.get_width()
        height = self.get_height()
        if width <= 0 or height <= 0:
            return

        duration = max(self.props.duration, 0.0)
        fraction = (self.props.position / duration) if duration > 0 else 0.0
        fraction = min(max(fraction, 0.0), 1.0)

        off = rgba(DOT_OFF)
        on = rgba(DOT_ON)
        accent = self.get_color()      # posée par le CSS
        segment_colours = {alpha: rgba(accent.to_string(), alpha)
                           for _s, _e, alpha in self.segments}
        centre_y = height / 2
        count = max(int(width // self.step), 1)

        for index in range(count):
            x = index * self.step + self.step / 2
            colour, radius = (on, self.radius + 0.2) if (x / width) <= fraction \
                else (off, self.radius)
            if duration > 0:
                at = (x / width) * duration
                for start, end, alpha in self.segments:
                    if start <= at <= end:
                        colour = segment_colours[alpha]
                        radius = self.radius + 0.2
                        break
            self._dot(snapshot, x, centre_y, radius, colour)

        if self.show_head and duration > 0:
            head_x = fraction * width
            # Anneau de la couleur du fond, puis pastille blanche par-dessus.
            self._dot(snapshot, head_x, centre_y, 10.0, rgba(HEAD_RING))
            self._dot(snapshot, head_x, centre_y, 6.0, rgba(HEAD_FILL))

    @staticmethod
    def _dot(snapshot: Gtk.Snapshot, x: float, y: float,
             radius: float, colour: Gdk.RGBA) -> None:
        rect = Graphene.Rect().init(x - radius, y - radius, radius * 2, radius * 2)
        rounded = Gsk.RoundedRect()
        rounded.init_from_rect(rect, radius)
        snapshot.push_rounded_clip(rounded)
        snapshot.append_color(colour, rect)
        snapshot.pop()

    # ---- Interaction ----------------------------------------------------

    def _position_at(self, x: float) -> float:
        width = max(self.get_width(), 1)
        ratio = min(max(x / width, 0.0), 1.0)
        return ratio * max(self.props.duration, 0.0)

    def _on_pressed(self, _gesture, _n_press: int, x: float, _y: float) -> None:
        self.grab_focus()
        if self.props.duration > 0:
            self.emit("seek-requested", self._position_at(x))

    def _on_drag_begin(self, _gesture, _x: float, _y: float) -> None:
        self._dragging = True

    def _on_drag_update(self, gesture, offset_x: float, _offset_y: float) -> None:
        ok, start_x, _ = gesture.get_start_point()
        if ok and self.props.duration > 0:
            # Aperçu immédiat : la position suit le doigt sans attendre le moteur.
            self.props.position = self._position_at(start_x + offset_x)

    def _on_drag_end(self, gesture, offset_x: float, _offset_y: float) -> None:
        self._dragging = False
        ok, start_x, _ = gesture.get_start_point()
        if ok and self.props.duration > 0:
            self.emit("seek-requested", self._position_at(start_x + offset_x))

    def _on_key(self, _controller, keyval: int, _keycode: int,
                _state: Gdk.ModifierType) -> bool:
        duration = self.props.duration
        if duration <= 0:
            return False
        target = None
        if keyval == Gdk.KEY_Left:
            target = self.props.position - SEEK_KEY_STEP
        elif keyval == Gdk.KEY_Right:
            target = self.props.position + SEEK_KEY_STEP
        elif keyval == Gdk.KEY_Home:
            target = 0.0
        elif keyval == Gdk.KEY_End:
            target = duration
        if target is None:
            return False
        self.emit("seek-requested", min(max(target, 0.0), duration))
        return True

    # ---- Accessibilité ---------------------------------------------------

    def _update_accessible(self) -> None:
        self.update_property(
            [Gtk.AccessibleProperty.LABEL], ["Progression de la lecture"])

    def do_measure(self, orientation, _for_size):
        if orientation == Gtk.Orientation.VERTICAL:
            height = max(self.bar_height, 16)
            return (height, height, -1, -1)
        return (int(self.step * 8), int(self.step * 8), -1, -1)

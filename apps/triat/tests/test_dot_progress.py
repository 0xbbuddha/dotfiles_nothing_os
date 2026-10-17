"""Tests du DotProgressBar : position, seek, segments."""

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import pytest
from gi.repository import Adw, Gtk

from triat.ui.widgets.dot_progress import DotProgressBar

Adw.init()


@pytest.fixture
def bar() -> DotProgressBar:
    widget = DotProgressBar()
    widget.props.duration = 200.0
    return widget


def test_starts_empty():
    widget = DotProgressBar()
    assert widget.props.position == 0.0
    assert widget.props.duration == 0.0
    assert widget.segments == []


def test_declares_slider_role_for_screen_readers():
    assert DotProgressBar().get_accessible_role() == Gtk.AccessibleRole.SLIDER


def test_segments_are_stored_as_floats(bar):
    bar.set_segments([(0, 22, 1.0), (180, 200, 0.7)])
    assert bar.segments == [(0.0, 22.0, 1.0), (180.0, 200.0, 0.7)]


def test_clear_resets_everything(bar):
    bar.set_segments([(0, 10, 1.0)])
    bar.props.position = 50.0
    bar.clear()
    assert bar.segments == [] and bar.props.position == 0.0


def test_keyboard_seek_emits_target(bar):
    from gi.repository import Gdk

    seen = []
    bar.connect("seek-requested", lambda _w, value: seen.append(value))
    bar.props.position = 100.0
    bar._on_key(None, Gdk.KEY_Right, 0, Gdk.ModifierType(0))
    bar._on_key(None, Gdk.KEY_Left, 0, Gdk.ModifierType(0))
    assert seen == [105.0, 95.0]


def test_keyboard_seek_is_clamped(bar):
    from gi.repository import Gdk

    seen = []
    bar.connect("seek-requested", lambda _w, value: seen.append(value))
    bar.props.position = 1.0
    bar._on_key(None, Gdk.KEY_Left, 0, Gdk.ModifierType(0))
    bar.props.position = 199.0
    bar._on_key(None, Gdk.KEY_Right, 0, Gdk.ModifierType(0))
    assert seen == [0.0, 200.0], "jamais hors de [0, durée]"


def test_home_and_end(bar):
    from gi.repository import Gdk

    seen = []
    bar.connect("seek-requested", lambda _w, value: seen.append(value))
    bar._on_key(None, Gdk.KEY_Home, 0, Gdk.ModifierType(0))
    bar._on_key(None, Gdk.KEY_End, 0, Gdk.ModifierType(0))
    assert seen == [0.0, 200.0]


def test_no_seek_without_duration():
    from gi.repository import Gdk

    widget = DotProgressBar()
    seen = []
    widget.connect("seek-requested", lambda _w, value: seen.append(value))
    assert widget._on_key(None, Gdk.KEY_Right, 0, Gdk.ModifierType(0)) is False
    assert seen == [], "rien à chercher quand aucune piste n'est chargée"

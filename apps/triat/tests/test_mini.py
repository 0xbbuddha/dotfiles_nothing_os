"""Tests du mini-lecteur."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import pytest
from gi.repository import Adw

from triat.core.engine import Engine
from triat.core.library import Library
from triat.core.models import TrackRef
from triat.core.settings import Settings
from triat.ui.mini_player import MiniPlayer
from tests.fakes import (FakeCookies, FakeExtractor, FakeInnerTube,
                         FakePlayer, FakeRecommender, FakeSponsorBlock)

Adw.init()


@pytest.fixture(scope="session")
def application():
    app = Adw.Application(application_id="org.triat.TriatMiniTest")
    app.register(None)
    app.emit("startup")
    return app


@pytest.fixture
def engine(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", False)
    eng = Engine(settings=settings, library=Library(tmp_path / "l.db"),
                 player=FakePlayer(), extractor=FakeExtractor(),
                 sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
                 ytmusic=object(), cookies=FakeCookies(),
                 innertube=FakeInnerTube())
    yield eng
    eng.library.close()


def test_mini_builds(application, engine):
    mini = MiniPlayer(application, engine)
    assert mini.get_title() == "Triat — mini"
    assert not mini.get_resizable()
    assert not mini.get_decorated()


def test_mini_shows_the_track(application, engine):
    mini = MiniPlayer(application, engine)
    engine.emit("track-changed", TrackRef("m" * 11, "Titre", "Artiste", 180.0))
    assert mini._title.get_text() == "Titre"
    assert mini._artist.get_text() == "Artiste"
    assert mini.progress.props.duration == 180.0


def test_mini_transport_reaches_the_engine(application, engine):
    mini = MiniPlayer(application, engine)
    mini.progress.props.duration = 100.0
    mini.progress.emit("seek-requested", 30.0)
    assert engine.player.seeks[-1] == 30.0


def test_mini_resets_when_nothing_plays(application, engine):
    mini = MiniPlayer(application, engine)
    engine.emit("track-changed", TrackRef("n" * 11, "T", "A", 90.0))
    engine.emit("track-changed", None)
    assert mini._title.get_text() == "Rien en lecture"
    assert mini.progress.props.duration == 0.0


def test_play_icon_follows_state(application, engine):
    mini = MiniPlayer(application, engine)
    engine.emit("state-changed", "playing")
    assert mini.play_button.get_icon_name() == "triat-pause-symbolic"
    engine.emit("state-changed", "paused")
    assert mini.play_button.get_icon_name() == "triat-play-symbolic"

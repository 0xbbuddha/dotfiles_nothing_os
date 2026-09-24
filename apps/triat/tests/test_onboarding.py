"""Tests de l'écran de bienvenue."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import pytest
from gi.repository import Adw

from triat.core.engine import Engine
from triat.core.library import Library
from triat.core.settings import Settings
from triat.ui.onboarding import STEPS, OnboardingView
from tests.fakes import (FakeCookies, FakeExtractor, FakeInnerTube,
                         FakePlayer, FakeRecommender, FakeSponsorBlock)

Adw.init()


@pytest.fixture
def engine(tmp_path):
    settings = Settings(tmp_path / "s.json")
    eng = Engine(settings=settings, library=Library(tmp_path / "l.db"),
                 player=FakePlayer(), extractor=FakeExtractor(),
                 sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
                 ytmusic=object(), cookies=FakeCookies(),
                 innertube=FakeInnerTube())
    yield eng
    eng.library.close()


def test_starts_on_the_first_step(engine):
    view = OnboardingView(engine, lambda: None)
    assert view._step == 0
    assert view._step_label.get_text().startswith("Étape 1 sur")


def test_walks_through_every_step(engine):
    done = []
    view = OnboardingView(engine, lambda: done.append(True))
    for _ in range(STEPS - 1):
        view._next()
    assert view._step == STEPS - 1
    assert not done, "pas fini avant la dernière étape"
    view._next()
    assert done == [True]


def test_finishing_marks_the_setting(engine):
    view = OnboardingView(engine, lambda: None)
    for _ in range(STEPS):
        view._next()
    assert engine.settings.get("onboarding_done") is True


def test_sponsorblock_toggle_persists(engine):
    view = OnboardingView(engine, lambda: None)
    view._set("sponsorblock_enabled", False)
    assert engine.settings.get("sponsorblock_enabled") is False


def test_browser_detection_returns_known_names(engine):
    detected = OnboardingView._detect_browsers()
    assert isinstance(detected, list)
    assert all(isinstance(name, str) for name in detected)


def test_skip_is_only_offered_on_the_account_step(engine):
    view = OnboardingView(engine, lambda: None)
    assert view._skip.get_visible()
    view._next()
    assert not view._skip.get_visible()

"""Tests de la page Artiste et des requêtes par artiste."""

from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

import pytest
from gi.repository import Adw

from triat.core.library import Library
from triat.core.models import TrackRef

Adw.init()


@pytest.fixture
def library(tmp_path):
    lib = Library(tmp_path / "l.db")
    lib.upsert_many([
        TrackRef("a" * 11, "Un", "Daft Punk"),
        TrackRef("b" * 11, "Deux", "daft punk"),      # casse différente
        TrackRef("c" * 11, "Trois", "  Daft Punk  "),  # espaces
        TrackRef("d" * 11, "Quatre", "Autre Groupe"),
        TrackRef("e" * 11, "Cinq", ""),
    ])
    yield lib
    lib.close()


def test_artist_lookup_ignores_case_and_spaces(library):
    found = library.tracks_by_artist("DAFT PUNK")
    assert {t.title for t in found} == {"Un", "Deux", "Trois"}


def test_unknown_artist_returns_nothing(library):
    assert library.tracks_by_artist("Personne") == []


def test_empty_artist_is_refused(library):
    assert library.tracks_by_artist("") == []
    assert library.tracks_by_artist("   ") == []


def test_artist_listing_counts_and_sorts(library):
    listing = dict(library.artists())
    assert listing.get("Daft Punk") == 3 or listing.get("daft punk") == 3
    assert "Autre Groupe" in listing
    assert "" not in listing, "les pistes sans artiste sont écartées"


def test_most_prolific_artist_comes_first(library):
    assert library.artists()[0][1] == 3

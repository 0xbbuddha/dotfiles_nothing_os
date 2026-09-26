"""Mixes de l'accueil : locaux, stables sur la journée, variés."""

from __future__ import annotations

import datetime as dt

import pytest

from triat.core.library import Library
from triat.core.mixes import MIX_SIZE, build_mixes
from triat.core.models import TrackRef


@pytest.fixture
def library(tmp_path):
    lib = Library(tmp_path / "l.db")
    refs = []
    for artist, n in (("Vialice", 10), ("LEDOUBLE", 6), ("Solo", 1)):
        refs += [TrackRef(f"{artist[:3]}{i:03d}", f"{artist} {i}", artist, 180.0)
                 for i in range(n)]
    refs += [TrackRef(f"misc{i:03d}", f"Divers {i}", f"Autre {i}", 200.0)
             for i in range(40)]
    lib.upsert_many(refs)
    # Une playlist qui intercale Vialice et des inconnus.
    pid = lib.create_playlist("Mix 217")
    lib.add_to_playlist(pid, [r for pair in zip(refs[:10], refs[20:30])
                              for r in pair])
    yield lib
    lib.close()


def test_empty_library_has_no_mix(tmp_path):
    lib = Library(tmp_path / "vide.db")
    assert build_mixes(lib) == []
    lib.close()


def test_daily_mix_is_stable_within_a_day(library):
    day = dt.date(2026, 9, 23)
    a = build_mixes(library, day)[0]
    b = build_mixes(library, day)[0]
    other = build_mixes(library, dt.date(2026, 9, 24))[0]
    assert a.title == "Mix du jour"
    assert [r.video_id for r in a.refs] == [r.video_id for r in b.refs]
    assert [r.video_id for r in a.refs] != [r.video_id for r in other.refs]
    assert len(a.refs) == MIX_SIZE
    assert len({r.video_id for r in a.refs}) == MIX_SIZE


def test_artist_mix_mixes_artist_and_playlist_neighbours(library):
    mixes = {m.title: m for m in build_mixes(library, dt.date(2026, 9, 23))}
    vialice = mixes["Mix Vialice"]
    artists = [r.artist for r in vialice.refs]
    assert artists[0] == "Vialice"
    assert "Vialice" in artists and any(a.startswith("Autre") for a in artists)
    assert "Mix Solo" not in mixes          # une seule piste : pas de mix


def test_subtitle_names_the_first_artists():
    from triat.core.mixes import Mix
    mix = Mix("k", "t", [TrackRef("a", "x", "A"), TrackRef("b", "y", "B"),
                         TrackRef("c", "z", "A"), TrackRef("d", "w", "C")])
    assert mix.subtitle == "4 titres, avec A, B et C"


def test_playlist_neighbours(library):
    near = library.playlist_neighbours(["Via000"], radius=1)
    assert [r.video_id for r in near] == ["misc003"]   # refs[20]

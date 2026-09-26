"""Tests des paroles : parsing LRC, suivi, cache, repli.

Les textes de ces tests sont inventés : rien n'est repris d'une œuvre.
"""

from __future__ import annotations

import io
import json

import pytest

from triat.core.library import Library
from triat.core.lyrics import Lyrics, LyricsService, parse_lrc
from triat.core.models import TrackRef


# ---- Parsing --------------------------------------------------------------

def test_timestamps_are_parsed():
    lignes = parse_lrc("[00:12.30]Alpha\n[01:05.00]Bravo\n[02:00]Charlie")
    assert lignes == [(12.3, "Alpha"), (65.0, "Bravo"), (120.0, "Charlie")]


def test_lines_are_sorted_even_if_the_file_is_not():
    lignes = parse_lrc("[01:00.00]Deux\n[00:30.00]Un")
    assert [t for _s, t in lignes] == ["Un", "Deux"]


def test_malformed_lines_are_skipped():
    lignes = parse_lrc("pas d'horodatage\n[00:05.00]Valide\n[xx:yy]Invalide\n")
    assert lignes == [(5.0, "Valide")]


def test_fraction_precision_is_respected():
    assert parse_lrc("[00:01.5]A")[0][0] == 1.5
    assert parse_lrc("[00:01.05]A")[0][0] == 1.05
    assert parse_lrc("[00:01.500]A")[0][0] == 1.5


def test_empty_input_gives_no_lines():
    assert parse_lrc("") == []
    assert parse_lrc(None) == []


# ---- Suivi de la lecture --------------------------------------------------

@pytest.fixture
def paroles() -> Lyrics:
    return Lyrics(video_id="a" * 11, synced=True,
                  lines=[(0.0, "Un"), (10.0, "Deux"), (20.0, "Trois")])


def test_index_before_the_first_line_is_minus_one(paroles):
    assert Lyrics("x", True, [(5.0, "Un")]).index_at(2.0) == -1


def test_index_follows_the_position(paroles):
    assert paroles.index_at(0.0) == 0
    assert paroles.index_at(9.9) == 0
    assert paroles.index_at(10.0) == 1
    assert paroles.index_at(999.0) == 2


def test_index_without_lines_is_minus_one():
    assert Lyrics("x", False, []).index_at(30.0) == -1


def test_availability():
    assert not Lyrics("x", False, []).available
    assert Lyrics("x", True, [(0.0, "A")]).available
    assert Lyrics("x", False, [], plain="texte").available
    assert Lyrics("x", False, [], instrumental=True).available


# ---- Service --------------------------------------------------------------

class _Response(io.BytesIO):
    def __enter__(self): return self
    def __exit__(self, *_): return False


def test_a_track_without_title_is_not_looked_up(tmp_path, monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen",
                        lambda *a, **k: pytest.fail("aucune requête attendue"))
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(TrackRef("b" * 11, ""))
    assert not result.available
    library.close()


def test_network_failure_is_not_fatal(tmp_path, monkeypatch):
    def explode(*_a, **_k):
        raise OSError("réseau coupé")

    monkeypatch.setattr("urllib.request.urlopen", explode)
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(TrackRef("c" * 11, "Titre", "Artiste"))
    assert not result.available, "pas de paroles, mais pas d'exception"
    library.close()


def test_closest_duration_wins(tmp_path, monkeypatch):
    """Deux versions d'un titre : celle dont la durée colle est retenue."""
    payload = [
        {"trackName": "T", "duration": 200.0, "syncedLyrics": _lrc("Court")},
        {"trackName": "T", "duration": 301.0, "syncedLyrics": _lrc("Long")},
    ]

    def fake(request, **_kwargs):
        if "/get?" in request.full_url:
            raise OSError("pas de correspondance exacte")
        return _Response(json.dumps(payload).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake)
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(
        TrackRef("d" * 11, "T", "A", duration=300.0))
    assert result.lines[0][1] == "Long"
    library.close()


def test_result_is_cached(tmp_path, monkeypatch):
    calls = {"n": 0}

    def fake(request, **_kwargs):
        calls["n"] += 1
        return _Response(json.dumps({
            "syncedLyrics": _lrc("Ligne"), "plainLyrics": "",
            "instrumental": False}).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake)
    library = Library(tmp_path / "l.db")
    service = LyricsService(library)
    ref = TrackRef("e" * 11, "Titre", "Artiste", duration=120.0)

    first = service.fetch(ref)
    before = calls["n"]
    second = service.fetch(ref)

    assert first.lines == second.lines
    assert calls["n"] == before, "le second appel ne doit pas sortir sur le réseau"
    library.close()


def test_instrumental_is_reported(tmp_path, monkeypatch):
    def fake(*_a, **_k):
        return _Response(json.dumps({
            "instrumental": True, "syncedLyrics": "", "plainLyrics": ""}).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake)
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(TrackRef("f" * 11, "T", "A", 100.0))
    assert result.instrumental and result.available
    library.close()


def _lrc(first: str, n: int = 6) -> str:
    return "\n".join(f"[00:{i * 5:02d}.00]{first if i == 0 else f'l{i}'}"
                     for i in range(n))


def test_vandalised_exact_match_falls_back_to_search(tmp_path, monkeypatch):
    """LRCLIB sert réellement « probe » pour « Never Gonna Give You Up »."""
    def fake(request, **_kwargs):
        if "/get?" in request.full_url:
            return _Response(json.dumps({
                "duration": 214.0, "syncedLyrics": "[00:00.00]probe",
                "plainLyrics": "probe", "instrumental": False}).encode())
        return _Response(json.dumps([
            {"duration": 213.0, "syncedLyrics": "[00:00.00]probe"},
            {"duration": 215.0, "syncedLyrics": _lrc("We're no strangers")},
        ]).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake)
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(
        TrackRef("h" * 11, "Never Gonna Give You Up", "Rick Astley", 213.0))
    assert result.lines[0][1] == "We're no strangers"
    library.close()


def test_only_junk_means_no_lyrics(tmp_path, monkeypatch):
    def fake(request, **_kwargs):
        if "/get?" in request.full_url:
            raise OSError("pas de correspondance exacte")
        return _Response(json.dumps(
            [{"duration": 213.0, "syncedLyrics": "[00:00.00]probe"}]).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake)
    library = Library(tmp_path / "l.db")
    result = LyricsService(library).fetch(TrackRef("i" * 11, "T", "A", 213.0))
    assert not result.available
    library.close()


@pytest.mark.network
def test_real_lrclib_contract():
    """Contrat réel de LRCLIB (nécessite le réseau)."""
    service = LyricsService()
    result = service.fetch(TrackRef("g" * 11, "Instant Crush", "Daft Punk", 337.0))
    assert result.available
    assert all(isinstance(s, float) and isinstance(t, str) for s, t in result.lines)

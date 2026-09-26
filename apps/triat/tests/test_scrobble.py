"""Tests du scrobbling ListenBrainz."""

from __future__ import annotations

import io
import json

import pytest

from triat.core import scrobble
from triat.core.models import TrackRef
from triat.core.scrobble import ScrobbleError, Scrobbler, should_submit
from triat.core.settings import Settings


# ---- Règles de comptage ---------------------------------------------------

@pytest.mark.parametrize("played,duration,expected", [
    (10.0, 200.0, False),      # trop court
    (100.0, 200.0, True),      # moitié atteinte
    (99.0, 200.0, False),      # juste en dessous
    (250.0, 3600.0, True),     # 4 minutes sur un long morceau
    (200.0, 3600.0, False),
    (20.0, 25.0, False),       # piste de moins de 30 s
    (60.0, 0.0, False),        # durée inconnue, moins de 4 min
    (300.0, 0.0, True),
])
def test_listen_counts_only_when_it_should(played, duration, expected):
    assert should_submit(played, duration) is expected


# ---- Jeton ----------------------------------------------------------------

class _Response(io.BytesIO):
    def __enter__(self): return self
    def __exit__(self, *_): return False


@pytest.fixture
def scrobbler(tmp_path, monkeypatch):
    store = {}
    monkeypatch.setattr(scrobble.keyring, "set_password",
                        lambda s, k, v: store.__setitem__((s, k), v))
    monkeypatch.setattr(scrobble.keyring, "get_password",
                        lambda s, k: store.get((s, k)))
    monkeypatch.setattr(scrobble.keyring, "delete_password",
                        lambda s, k: store.pop((s, k), None))
    return Scrobbler(Settings(tmp_path / "s.json"))


def test_disabled_without_a_token(scrobbler):
    assert not scrobbler.enabled


def test_a_valid_token_is_stored(scrobbler, monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen", lambda *a, **k: _Response(
        json.dumps({"valid": True, "user_name": "demo"}).encode()))
    assert scrobbler.set_token("abc") == "demo"
    assert scrobbler.enabled
    assert scrobbler._settings.get("scrobble_user") == "demo"


def test_an_invalid_token_is_refused(scrobbler, monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen", lambda *a, **k: _Response(
        json.dumps({"valid": False}).encode()))
    with pytest.raises(ScrobbleError, match="refusé"):
        scrobbler.set_token("mauvais")
    assert not scrobbler.enabled, "rien n'est stocké quand le jeton est mauvais"


def test_an_empty_token_is_refused(scrobbler):
    with pytest.raises(ScrobbleError, match="vide"):
        scrobbler.set_token("   ")


def test_clearing_removes_everything(scrobbler, monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen", lambda *a, **k: _Response(
        json.dumps({"valid": True, "user_name": "x"}).encode()))
    scrobbler.set_token("abc")
    scrobbler.clear()
    assert not scrobbler.enabled
    assert scrobbler._settings.get("scrobble_user") == ""


# ---- Envoi ----------------------------------------------------------------

def test_nothing_is_sent_without_a_token(scrobbler, monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen",
                        lambda *a, **k: pytest.fail("aucun envoi attendu"))
    assert scrobbler.submit(TrackRef("a" * 11, "T", "A", 200.0), 150.0, 200.0) \
        is False


def test_metadata_carry_the_essentials(scrobbler):
    ref = TrackRef("a" * 11, "Titre", "Artiste", 200.0, album="Album")
    data = scrobbler._metadata(ref)
    assert data["artist_name"] == "Artiste"
    assert data["track_name"] == "Titre"
    assert data["release_name"] == "Album"
    assert data["additional_info"]["media_player"] == "Triat"


def test_missing_metadata_fall_back(scrobbler):
    data = scrobbler._metadata(TrackRef("a" * 11, "", ""))
    assert data["artist_name"] == "Inconnu"
    assert data["track_name"] == "Inconnu"


def test_a_network_failure_is_swallowed(scrobbler, monkeypatch):
    monkeypatch.setattr(scrobble.keyring, "get_password", lambda s, k: "jeton")
    scrobbler._settings.set("scrobble_enabled", True)

    def explode(*_a, **_k):
        raise OSError("réseau coupé")

    monkeypatch.setattr("urllib.request.urlopen", explode)
    scrobbler._post({"listen_type": "single", "payload": []})   # ne lève pas

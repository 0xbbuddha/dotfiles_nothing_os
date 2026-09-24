"""Tests des cookies : validation, stockage, permissions, effacement.

Le vrai trousseau n'est jamais touché : `keyring` est remplacé par un
dictionnaire en mémoire.
"""

import os
import time

import pytest

from triat.core import auth
from triat.core.auth import CookieError, CookieManager

NOW = time.time()
SAMPLE = "\n".join([
    "# Netscape HTTP Cookie File",
    f".youtube.com\tTRUE\t/\tTRUE\t{int(NOW + 30 * 86400)}\tSID\tvaleur-sid",
    f".youtube.com\tTRUE\t/\tTRUE\t{int(NOW + 10 * 86400)}\t__Secure-3PSID\tvaleur-3psid",
    ".youtube.com\tTRUE\t/\tFALSE\t0\tPREF\tf1=40000000",
    ".example.com\tTRUE\t/\tFALSE\t0\tAUTRE\tpas-youtube",
])


class FakeKeyring:
    def __init__(self):
        self.store = {}

    def set_password(self, service, key, value):
        self.store[(service, key)] = value

    def get_password(self, service, key):
        return self.store.get((service, key))

    def delete_password(self, service, key):
        if (service, key) not in self.store:
            raise auth.keyring.errors.PasswordDeleteError("absent")
        del self.store[(service, key)]


@pytest.fixture
def manager(tmp_path, monkeypatch):
    fake = FakeKeyring()
    monkeypatch.setattr(auth.keyring, "set_password", fake.set_password)
    monkeypatch.setattr(auth.keyring, "get_password", fake.get_password)
    monkeypatch.setattr(auth.keyring, "delete_password", fake.delete_password)
    monkeypatch.setattr(auth, "runtime_dir", lambda: tmp_path)
    mgr = CookieManager()
    mgr._runtime_path = tmp_path / "cookies.txt"
    return mgr


@pytest.fixture
def cookie_file(tmp_path):
    path = tmp_path / "cookies.txt.source"
    path.write_text(SAMPLE, encoding="utf-8")
    return path


def test_no_cookies_by_default(manager):
    status = manager.status()
    assert not status.present and not status.authenticated
    assert manager.cookie_file() is None
    assert manager.ytdlp_opts() == {}


def test_import_detects_authenticated_session(manager, cookie_file):
    status = manager.import_file(cookie_file)
    assert status.present and status.authenticated
    assert status.count == 4
    assert 9 < status.days_left < 11, "on retient l'expiration la plus proche"
    assert not status.expired


def test_rejects_a_file_that_is_not_netscape(manager, tmp_path):
    bad = tmp_path / "bad.txt"
    bad.write_text("{\"cookies\": []}", encoding="utf-8")
    with pytest.raises(CookieError, match="Format non reconnu"):
        manager.import_file(bad)


def test_rejects_missing_file(manager, tmp_path):
    with pytest.raises(CookieError, match="Lecture impossible"):
        manager.import_file(tmp_path / "nexiste.pas")


def test_materialized_file_is_private(manager, cookie_file):
    manager.import_file(cookie_file)
    path = manager.cookie_file()
    assert path is not None
    mode = os.stat(path).st_mode & 0o777
    assert mode == 0o600, f"le fichier de cookies doit être 0600, trouvé {oct(mode)}"


def test_ytdlp_opts_point_to_the_file(manager, cookie_file):
    manager.import_file(cookie_file)
    opts = manager.ytdlp_opts()
    assert opts["cookiefile"] == manager.cookie_file()


def test_cookie_header_keeps_only_google_domains(manager, cookie_file):
    manager.import_file(cookie_file)
    header = manager.cookie_header()
    assert "SID=valeur-sid" in header
    assert "PREF=f1=40000000" in header
    assert "AUTRE" not in header, "les cookies d'autres domaines ne partent pas"


def test_clear_removes_secret_and_file(manager, cookie_file):
    manager.import_file(cookie_file)
    path = manager.cookie_file()
    manager.clear()
    assert not os.path.exists(path)
    assert manager.cookie_file() is None
    assert not manager.status().present


def test_expired_session_is_flagged(manager, tmp_path):
    expired = tmp_path / "old.txt"
    expired.write_text(
        f".youtube.com\tTRUE\t/\tTRUE\t{int(NOW - 86400)}\tSID\tvieux",
        encoding="utf-8")
    status = manager.import_file(expired)
    assert status.expired and status.days_left == 0


def test_unknown_browser_is_refused(manager):
    with pytest.raises(CookieError, match="non pris en charge"):
        manager.import_from_browser("netscape-navigator")


def test_secret_is_not_written_to_the_settings_file(manager, cookie_file, tmp_path):
    from triat.core.settings import Settings

    settings = Settings(tmp_path / "settings.json")
    manager._settings = settings
    manager.import_file(cookie_file)
    dumped = (tmp_path / "settings.json").read_text(encoding="utf-8")
    assert "valeur-sid" not in dumped, "aucune valeur de cookie en clair dans la config"
    assert settings.get("cookie_source")["kind"] == "file"


JSON_EXPORT = """[
 {"name":"VISITOR_INFO1_LIVE","value":"abc","domain":".youtube.com",
  "hostOnly":false,"path":"/","secure":true,"expirationDate":1805726407.673},
 {"name":"PREF","value":"tz=Europe.Paris","domain":".youtube.com",
  "hostOnly":false,"path":"/","secure":true,"expirationDate":1824734415.2},
 {"name":"HOSTONLY","value":"x","domain":"www.youtube.com",
  "hostOnly":true,"path":"/","secure":false,"session":true}
]"""


def test_json_export_is_accepted(manager, tmp_path):
    """Les extensions de navigateur exportent du JSON, pas du Netscape."""
    path = tmp_path / "cookies.json"
    path.write_text(JSON_EXPORT, encoding="utf-8")
    status = manager.import_file(path)
    assert status.present and status.count == 3
    header = manager.cookie_header()
    assert "VISITOR_INFO1_LIVE=abc" in header


def test_json_without_session_cookies_is_not_authenticated(manager, tmp_path):
    """Un export pris hors connexion ne débloque pas les recommandations."""
    path = tmp_path / "cookies.json"
    path.write_text(JSON_EXPORT, encoding="utf-8")
    assert manager.import_file(path).authenticated is False


def test_json_hostonly_flag_is_translated(manager, tmp_path):
    from triat.core.auth import _json_to_netscape

    netscape = _json_to_netscape(JSON_EXPORT)
    rows = [line.split("\t") for line in netscape.splitlines()
            if line and not line.startswith("#")]
    by_name = {r[5]: r for r in rows}
    assert by_name["VISITOR_INFO1_LIVE"][1] == "TRUE", "domaine + sous-domaines"
    assert by_name["HOSTONLY"][1] == "FALSE", "hôte exact uniquement"
    assert by_name["VISITOR_INFO1_LIVE"][3] == "TRUE", "drapeau secure conservé"


def test_plain_text_is_not_mistaken_for_json(manager, tmp_path):
    from triat.core.auth import _json_to_netscape

    assert _json_to_netscape("pas du json") is None
    assert _json_to_netscape("[]") is None, "une liste vide n'est pas exploitable"

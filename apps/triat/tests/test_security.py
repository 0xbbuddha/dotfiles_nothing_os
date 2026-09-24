"""Tests de sécurité — chaque test correspond à un défaut corrigé.

Ils existent pour empêcher une régression silencieuse, pas pour la forme.
"""

import os
import stat

import pytest

from triat.core.net import (
    MEDIA_HOST_SUFFIXES,
    UnsafeURL,
    check_url,
    is_safe_url,
    safe_media_url,
    sanitize_headers,
)


# ---- Schémas et adresses -------------------------------------------------

@pytest.mark.parametrize("url", [
    "file:///etc/passwd",
    "file://localhost/etc/shadow",
    "ftp://exemple.test/x",
    "gopher://exemple.test/",
    "data:text/html,<script>",
    "javascript:alert(1)",
    "/etc/passwd",
    "",
])
def test_dangerous_schemes_are_refused(url):
    assert not is_safe_url(url)


@pytest.mark.parametrize("url", [
    "http://127.0.0.1:8080/admin",
    "https://localhost/",
    "http://169.254.169.254/latest/meta-data/",   # métadonnées cloud
    "http://10.0.0.1/",
    "http://192.168.1.1/",
    "http://[::1]/",
])
def test_internal_addresses_are_refused(url):
    assert not is_safe_url(url), "une URL d'API ne doit pas viser le réseau local"


def test_public_https_is_accepted():
    assert is_safe_url("https://www.youtube.com/watch?v=abc")


def test_media_urls_are_restricted_to_google_domains():
    assert safe_media_url("https://i.ytimg.com/vi/abc/hq.jpg")
    assert safe_media_url("https://rr2---sn-x.googlevideo.com/videoplayback?x=1")
    with pytest.raises(UnsafeURL, match="hors périmètre"):
        safe_media_url("https://attaquant.test/pochette.jpg")


def test_lookalike_domain_is_refused():
    """`ytimg.com.attaquant.test` ne doit pas passer pour `ytimg.com`."""
    with pytest.raises(UnsafeURL):
        safe_media_url("https://ytimg.com.attaquant.test/x.jpg")
    with pytest.raises(UnsafeURL):
        safe_media_url("https://notyoutube.com/x.jpg")


def test_allow_hosts_accepts_subdomains():
    assert check_url("https://music.youtube.com/", allow_hosts=("youtube.com",))


# ---- En-têtes HTTP passés à mpv ------------------------------------------

def test_header_injection_is_stripped():
    fields = sanitize_headers({
        "User-Agent": "Triat/0.1",
        "X-Bad": "valeur\r\nCookie: vole=1",
        "Y-Bad\nInjected": "x",
        "Z-Null": "a\x00b",
    })
    assert fields == ["User-Agent: Triat/0.1"]
    assert not any("Cookie" in f for f in fields)


def test_empty_headers_give_empty_list():
    assert sanitize_headers({}) == []
    assert sanitize_headers(None) == []


# ---- Fichier de cookies ---------------------------------------------------

def test_cookie_file_is_forced_to_0600_even_if_it_already_exists(tmp_path, monkeypatch):
    """Un fichier préexistant trop permissif doit être resserré."""
    from triat.core import auth
    from triat.core.auth import CookieManager

    store = {}
    monkeypatch.setattr(auth.keyring, "set_password",
                        lambda s, k, v: store.__setitem__((s, k), v))
    monkeypatch.setattr(auth.keyring, "get_password",
                        lambda s, k: store.get((s, k)))
    monkeypatch.setattr(auth, "runtime_dir", lambda: tmp_path)

    manager = CookieManager()
    manager._runtime_path = tmp_path / "cookies.txt"
    # Fichier laissé lisible par tout le monde par une exécution antérieure.
    manager._runtime_path.write_text("ancien", encoding="utf-8")
    manager._runtime_path.chmod(0o644)

    source = tmp_path / "in.txt"
    source.write_text(".youtube.com\tTRUE\t/\tTRUE\t0\tSID\tv", encoding="utf-8")
    manager.import_file(source)

    path = manager.cookie_file()
    mode = stat.S_IMODE(os.stat(path).st_mode)
    assert mode == 0o600, f"attendu 0600, trouvé {oct(mode)}"


def test_cookie_file_refuses_a_symlink(tmp_path, monkeypatch):
    """Un lien symbolique à la place du fichier ne doit pas être suivi."""
    from triat.core import auth
    from triat.core.auth import CookieManager

    store = {}
    monkeypatch.setattr(auth.keyring, "set_password",
                        lambda s, k, v: store.__setitem__((s, k), v))
    monkeypatch.setattr(auth.keyring, "get_password",
                        lambda s, k: store.get((s, k)))
    monkeypatch.setattr(auth, "runtime_dir", lambda: tmp_path)

    manager = CookieManager()
    manager._runtime_path = tmp_path / "cookies.txt"
    cible = tmp_path / "cible.txt"
    cible.write_text("", encoding="utf-8")
    manager._runtime_path.symlink_to(cible)

    source = tmp_path / "in.txt"
    source.write_text(".youtube.com\tTRUE\t/\tTRUE\t0\tSID\tsecret", encoding="utf-8")
    manager.import_file(source)
    manager.cookie_file()

    assert cible.read_text(encoding="utf-8") == "", \
        "les cookies ne doivent pas avoir été écrits au bout du lien"
    assert not manager._runtime_path.is_symlink()


# ---- Extraction -----------------------------------------------------------

def test_extractor_refuses_local_schemes():
    from triat.core.extractor import ExtractionError, Extractor

    for url in ("file:///etc/passwd", "ftp://exemple.test/a"):
        with pytest.raises(ExtractionError):
            Extractor().resolve(url)


def test_plain_words_are_still_treated_as_a_search():
    """La validation d'URL ne doit pas casser la recherche par mots-clés."""
    from triat.core.extractor import Extractor

    extractor = Extractor()
    captured = {}

    class FakeYDL:
        def __init__(self, opts): pass
        def __enter__(self): return self
        def __exit__(self, *a): return False
        def extract_info(self, query, download=False):
            captured["query"] = query
            return {"_type": "playlist", "entries": [{
                "id": "x" * 11, "title": "T", "url": "https://exemple.test/s",
                "duration": 1, "webpage_url": "https://exemple.test"}]}

    import yt_dlp
    original = yt_dlp.YoutubeDL
    yt_dlp.YoutubeDL = FakeYDL
    try:
        extractor.resolve("daft punk")
    finally:
        yt_dlp.YoutubeDL = original
    assert captured["query"].startswith("ytsearch1:")


# ---- Lecteur --------------------------------------------------------------

def test_headers_do_not_leak_between_tracks():
    """Les en-têtes d'une piste ne doivent pas partir avec la suivante."""
    from triat.core.models import Track

    class FakeMpv:
        def __init__(self): self.http_header_fields = ["Cookie: ancien=1"]
        def play(self, url): pass

    from triat.core import player as player_module

    sent = FakeMpv()
    # On rejoue la logique d'affectation sans instancier libmpv.
    track = Track(video_id="b" * 11, title="T", artist="A", duration=1.0,
                  stream_url="https://exemple.test/s", webpage_url="",
                  http_headers={})
    sent.http_header_fields = player_module.sanitize_headers(track.http_headers)
    assert sent.http_header_fields == [], \
        "une piste sans en-tête doit effacer ceux de la précédente"


# ---- Recherche locale -----------------------------------------------------

@pytest.mark.parametrize("query", [
    '" OR 1=1 --', "*", "^", "NEAR(", "a:b", "-x", "((((", 'x" AND "y',
])
def test_search_never_crashes_on_hostile_input(tmp_path, query):
    from triat.core.library import Library
    from triat.core.models import TrackRef

    lib = Library(tmp_path / "s.db")
    lib.upsert_track(TrackRef("a" * 11, "Titre", "Artiste"))
    assert isinstance(lib.search(query), list)
    lib.close()


def test_search_still_works_after_hardening(tmp_path):
    from triat.core.library import Library
    from triat.core.models import TrackRef

    lib = Library(tmp_path / "s.db")
    lib.upsert_track(TrackRef("a" * 11, "Instant Crush", "Daft Punk"))
    assert [t.title for t in lib.search("instant")] == ["Instant Crush"]
    lib.close()


@pytest.mark.parametrize("url", [
    "https://localhost/",
    "http://LOCALHOST./",              # casse et point final
    "http://api.localhost/",
    "http://nas.local/",
    "http://svc.internal/",
])
def test_local_hostnames_are_refused(url):
    """`localhost` est un nom, pas une adresse : il doit aussi être bloqué."""
    assert not is_safe_url(url)


# ---- Résilience de l'extraction -------------------------------------------

@pytest.mark.parametrize("message", [
    "ERROR: No video formats found!",
    "The page needs to be reloaded.",
    "Sign in to confirm you're not a bot",
    "This video requires a PO Token to continue",
])
def test_blocking_errors_trigger_a_retry(message):
    from triat.core.extractor import is_retryable

    assert is_retryable(message)


@pytest.mark.parametrize("message", [
    "Video unavailable",
    "Private video",
    "This video has been removed by the uploader",
])
def test_real_failures_do_not_retry(message):
    from triat.core.extractor import is_retryable

    assert not is_retryable(message), "inutile de réessayer une piste morte"


def test_client_fallback_order_starts_with_the_default():
    from triat.core.extractor import CLIENT_FALLBACKS

    assert CLIENT_FALLBACKS[0] is None
    assert len(CLIENT_FALLBACKS) >= 3, "plusieurs replis, pas un seul"


# ---- Audit de production (2026-09-23) --------------------------------------

def test_corrupted_settings_never_block_startup(tmp_path):
    import json
    from triat.core.settings import DEFAULTS, Settings
    path = tmp_path / "s.json"
    path.write_text(json.dumps({
        "volume": "fort", "repeat": 42, "shuffle": "oui", "audio_quality": None,
        "eq_gains": "x", "sponsorblock_categories": [1, 2], "last_queue": {"a": 1},
        "last_index": "z", "immersion_mode": "vr", "scrobble_after_ratio": float("nan"),
        "future_key": 7}))
    s = Settings(path)
    for key in ("volume", "repeat", "shuffle", "audio_quality", "last_queue",
                "last_index", "immersion_mode", "scrobble_after_ratio"):
        assert s.get(key) == DEFAULTS[key], key
    assert s.get("sponsorblock_categories") == DEFAULTS["sponsorblock_categories"]
    assert s.get("future_key") == 7          # une clé d'une version future survit


def test_settings_that_are_not_an_object_fall_back(tmp_path):
    from triat.core.settings import DEFAULTS, Settings
    path = tmp_path / "s.json"
    path.write_text("[1, 2, 3]")
    assert Settings(path).get("volume") == DEFAULTS["volume"]


def test_valid_sponsorblock_policies_survive_bad_ones(tmp_path):
    import json
    from triat.core.settings import Settings
    path = tmp_path / "s.json"
    path.write_text(json.dumps({"sponsorblock_categories": {
        "intro": "ignore", "outro": "rm -rf", 3: "skip"}}))
    cats = Settings(path).get("sponsorblock_categories")
    assert cats["intro"] == "ignore" and cats["outro"] == "skip"


@pytest.mark.parametrize("video_id", ["../../etc", "a b", "x&list=1", "", 12, None,
                                      "a" * 65])
def test_restored_track_ids_are_validated(video_id):
    from triat.core.models import TrackRef
    with pytest.raises((ValueError, TypeError)):
        TrackRef.from_dict({"video_id": video_id, "title": "t"})


def test_restored_track_fields_are_typed():
    from triat.core.models import TrackRef
    ref = TrackRef.from_dict({"video_id": "dQw4w9WgXcQ", "title": 5,
                              "duration": "long", "artist": "A", "extra": 1})
    assert ref.title == "Sans titre" and ref.duration == 0.0 and ref.artist == "A"


def _redirect(req, newurl, allow=None):
    import io
    from email.message import Message
    from triat.core import net
    token = net._ALLOWED.set(allow)
    try:
        return net._CheckedRedirect().redirect_request(
            req, io.BytesIO(), 302, "Found", Message(), newurl)
    finally:
        net._ALLOWED.reset(token)


def test_redirect_to_another_host_drops_cookies():
    import urllib.request
    req = urllib.request.Request("https://www.youtube.com/a",
                                 headers={"Cookie": "SID=secret",
                                          "Authorization": "Token t",
                                          "User-Agent": "x"})
    new = _redirect(req, "https://cdn.example.org/b")
    names = {k.lower() for k in new.headers}
    assert "cookie" not in names and "authorization" not in names
    assert "user-agent" in names


def test_redirect_on_same_host_keeps_cookies():
    import urllib.request
    req = urllib.request.Request("https://www.youtube.com/a",
                                 headers={"Cookie": "SID=secret"})
    new = _redirect(req, "/b")
    assert new.full_url == "https://www.youtube.com/b"
    assert "SID=secret" in new.headers.values()


@pytest.mark.parametrize("target", ["https://evil.example/x",
                                    "http://127.0.0.1/admin",
                                    "file:///etc/passwd"])
def test_redirect_outside_allowed_hosts_is_refused(target):
    import urllib.request
    from triat.core.net import RedirectRefused
    req = urllib.request.Request("https://i.ytimg.com/vi/x/hq.jpg")
    with pytest.raises(RedirectRefused):
        _redirect(req, target, allow=("ytimg.com",))


def test_urlopen_checked_refuses_before_any_request(monkeypatch):
    from triat.core.net import RedirectRefused, urlopen_checked
    monkeypatch.setattr("urllib.request.urlopen",
                        lambda *a, **k: pytest.fail("aucune requête attendue"))
    with pytest.raises(RedirectRefused):
        urlopen_checked("https://evil.example/", 1, ("youtube.com",))


def _png(width: int, height: int) -> bytes:
    import struct
    import zlib
    def chunk(kind, body):
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + b"\x00\x00\x00" * width for _ in range(min(height, 2)))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class _Resp:
    def __init__(self, data): self._d = data
    def read(self, n=-1): return self._d
    def __enter__(self): return self
    def __exit__(self, *a): return False


@pytest.mark.parametrize("payload,accepted", [
    (_png(2, 2), True),
    (_png(50000, 50000), False),              # bombe de décompression
    (b"<html>not an image</html>", False),
])
def test_cover_cache_only_keeps_sane_images(tmp_path, monkeypatch, payload, accepted):
    from triat.core import artwork
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))
    monkeypatch.setattr("urllib.request.urlopen", lambda *a, **k: _Resp(payload))
    path = artwork.fetch("https://i.ytimg.com/vi/abc/hqdefault.jpg")
    assert (path is not None) is accepted
    leftovers = list((tmp_path / "triat" / "covers").glob("*.part"))
    assert leftovers == []


def test_cover_cache_is_pruned_oldest_first(tmp_path, monkeypatch):
    import os
    from triat.core import artwork
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path))
    folder = artwork.covers_dir()
    for i in range(5):
        f = folder / f"{i}.img"
        f.write_bytes(b"x" * 100)
        os.utime(f, (1000 + i, 1000 + i))
    assert artwork.prune(250) == 3
    assert sorted(p.name for p in folder.glob("*.img")) == ["3.img", "4.img"]


@pytest.mark.parametrize("url", ["https://soundcloud.com/a/b",
                                 "https://evil.example/watch?v=x",
                                 "https://youtube.com.evil.example/watch?v=x"])
def test_resolve_only_accepts_youtube(url):
    from triat.core.extractor import ExtractionError, Extractor
    with pytest.raises(ExtractionError):
        Extractor().resolve(url)
    with pytest.raises(ExtractionError):
        Extractor().resolve_video(url)


def test_download_template_escapes_percent(tmp_path, monkeypatch):
    import yt_dlp
    from triat.core.downloads import DownloadManager
    from triat.core.models import TrackRef
    monkeypatch.setenv("XDG_MUSIC_DIR", str(tmp_path))
    manager = DownloadManager()
    task = type("T", (), {"ref": TrackRef("abc", "50%(id)s off", "A")})()
    options = manager._options(task)
    name = yt_dlp.YoutubeDL({"outtmpl": options["outtmpl"], "quiet": True}) \
        .prepare_filename({"id": "zzz", "ext": "opus"})
    assert name.endswith("50%(id)s off.opus")


def test_corrupted_library_is_quarantined_not_fatal(tmp_path):
    from triat.core.library import Library
    from triat.core.models import TrackRef
    path = tmp_path / "library.db"
    path.write_text("ceci n'est pas une base sqlite")
    lib = Library(path)
    lib.upsert_track(TrackRef("dQw4w9WgXcQ", "T", "A"))
    assert lib.get_track("dQw4w9WgXcQ") is not None
    lib.close()
    kept = list(tmp_path.glob("library.db.corrompue-*"))
    assert kept and kept[0].read_text().startswith("ceci")


def test_log_file_is_private(tmp_path, monkeypatch):
    import logging
    import stat
    from triat.core import logs
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    import sys
    import threading
    monkeypatch.setattr(logs, "_done", False)
    monkeypatch.setattr(sys, "excepthook", sys.excepthook)
    monkeypatch.setattr(threading, "excepthook", threading.excepthook)
    root = logging.getLogger()
    before = list(root.handlers)
    try:
        logs.setup()
        logging.getLogger("triat.test").warning("bonjour")
        path = tmp_path / "triat" / "triat.log"
        assert "bonjour" in path.read_text()
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
    finally:
        for handler in root.handlers[len(before):]:
            root.removeHandler(handler)
            handler.close()

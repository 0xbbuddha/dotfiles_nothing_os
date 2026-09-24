"""Mise en forme des résultats de recherche (core/search_results.py)."""

from __future__ import annotations

from triat.core import search_results as sr
from triat.core.models import TrackRef


def ref(i: int, artist: str = "", title: str = "") -> TrackRef:
    return TrackRef(f"{i:011d}", title or f"T{i}", artist)


def test_normalize_ignores_case_and_accents():
    assert sr.normalize("  Beyoncé   KNOWLES ") == "beyonce knowles"


def test_clean_artist_drops_topic_suffix():
    assert sr.clean_artist("Daft Punk - Topic") == "Daft Punk"
    assert sr.clean_artist("Topic") == "Topic"


def test_tracks_are_merged_without_duplicates():
    a, b, c = ref(1), ref(2), ref(3)
    results = sr.build("x", [a, b], [b, c])
    assert [r.video_id for r in results.tracks] == [a.video_id, b.video_id, c.video_id]


def test_matching_artist_becomes_best_result():
    tracks = [ref(1, "Other"), ref(2, "Daft Punk - Topic"), ref(3, "Daft Punk")]
    results = sr.build("daft punk", tracks)
    assert results.best.kind == "artist"
    assert results.best.title == "Daft Punk"
    assert results.best.detail == "2 titres"
    assert results.artists[0] == ("Daft Punk", 2)


def test_short_prefix_does_not_pick_an_artist():
    results = sr.build("da", [ref(1, "Daft Punk")])
    assert results.best.kind == "track"


def test_playlist_named_like_query_wins_over_track():
    playlists = [{"id": 7, "name": "Été 2024", "item_count": 12},
                 {"id": 8, "name": "Hiver", "item_count": 3}]
    results = sr.build("ete 2024", [ref(1, "Quelqu'un")], playlists=playlists)
    assert [p["id"] for p in results.playlists] == [7]
    assert results.best.kind == "playlist"
    assert results.best.playlist_id == 7


def test_falls_back_to_first_track():
    results = sr.build("get lucky", [ref(1, "Daft Punk", "Get Lucky")])
    assert results.best.kind == "track"
    assert results.best.ref.video_id == ref(1).video_id


def test_nothing_found_is_empty():
    results = sr.build("zzz", [])
    assert results.empty and results.best is None


def test_history_puts_latest_first_without_duplicates():
    history = sr.remember_query(["daft punk", "justice"], "Justice")
    assert history == ["Justice", "daft punk"]


def test_history_skips_urls_and_bad_values():
    assert sr.remember_query(["a"], "https://youtu.be/x") == ["a"]
    assert sr.clean_history(["a", 3, "", None]) == ["a"]
    assert sr.clean_history("oops") == []


def test_history_is_capped():
    history = []
    for i in range(20):
        history = sr.remember_query(history, f"q{i}")
    assert len(history) == sr.HISTORY_SIZE and history[0] == "q19"


def test_innertube_skips_ads():
    """Une pub de recherche porte un lockup vidéo sans titre : à ignorer."""
    from triat.core.innertube import extract_refs
    lockup = {"lockupViewModel": {"contentId": "adadadadada", "contentType": "LOCKUP_CONTENT_TYPE_VIDEO"}}
    real = {"videoRenderer": {"videoId": "b" * 11, "title": {"runs": [{"text": "Get Lucky"}]}}}
    data = {"contents": [
        {"searchPyvRenderer": {"ads": [{"adSlotRenderer": {"fulfilledLayout": lockup}}]}},
        {"itemSectionRenderer": {"contents": [real]}},
    ]}
    assert [r.video_id for r in extract_refs(data)] == ["b" * 11]

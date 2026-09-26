"""Tests SponsorBlock : parsing, nettoyage, décision de saut."""

import io
import json
import urllib.error

import pytest

from triat.core.models import Segment
from triat.core.sponsorblock import (
    ASK,
    IGNORE,
    SKIP,
    SkipPlanner,
    SponsorBlockClient,
    merge_overlapping,
    sanitize,
    video_hash_prefix,
)

VIDEO = "jNQXAC9IVRw"


def test_hash_prefix_is_short_stable_and_not_the_id():
    prefix = video_hash_prefix(VIDEO)
    assert len(prefix) == 4
    assert prefix == video_hash_prefix(VIDEO)
    assert VIDEO not in prefix


def test_parse_keeps_only_the_requested_video():
    payload = [
        {"videoID": "autre", "segments": [
            {"segment": [0, 10], "category": "sponsor", "UUID": "x"}]},
        {"videoID": VIDEO, "segments": [
            {"segment": [5, 20.5], "category": "music_offtopic", "UUID": "ok"}]},
    ]
    segments = SponsorBlockClient._parse(payload, VIDEO)
    assert [s.uuid for s in segments] == ["ok"]
    assert segments[0].start == 5 and segments[0].end == 20.5


def test_parse_survives_malformed_entries():
    payload = [
        {"videoID": VIDEO, "segments": [
            {"segment": [0], "category": "sponsor"},              # tronqué
            {"category": "sponsor"},                               # pas de bornes
            {"segment": ["a", "b"], "category": "sponsor"},        # non numérique
            {"segment": [1, 2], "category": "intro", "UUID": "bon"},
        ]},
        "pas un objet",
    ]
    assert [s.uuid for s in SponsorBlockClient._parse(payload, VIDEO)] == ["bon"]


def test_merge_overlapping_collapses_duplicate_submissions():
    merged = merge_overlapping([
        Segment(0, 10, "sponsor", "a"),
        Segment(8, 15, "sponsor", "b"),
        Segment(30, 40, "outro", "c"),
    ])
    assert [(s.start, s.end) for s in merged] == [(0, 15), (30, 40)]


def test_merge_leaves_disjoint_segments_alone():
    merged = merge_overlapping([Segment(0, 5, "intro"), Segment(50, 60, "outro")])
    assert len(merged) == 2


def test_sanitize_drops_micro_and_absurd_segments():
    kept = sanitize([
        Segment(10, 10.3, "sponsor", "trop-court"),
        Segment(0, 195, "sponsor", "couvre-tout"),
        Segment(20, 35, "music_offtopic", "bon"),
        Segment(60, 50, "intro", "inverse"),
    ], duration=200.0)
    assert [s.uuid for s in kept] == ["bon"]


def test_planner_only_acts_on_enabled_categories():
    planner = SkipPlanner(
        [Segment(0, 12, "music_offtopic", "a"), Segment(100, 110, "filler", "b")],
        {"music_offtopic": SKIP, "filler": IGNORE},
    )
    assert planner.segment_at(5).uuid == "a"
    assert planner.segment_at(105) is None, "catégorie ignorée = pas de saut"
    assert planner.segment_at(50) is None


def test_planner_ask_policy_still_reports_the_segment():
    planner = SkipPlanner([Segment(0, 12, "intro", "a")], {"intro": ASK})
    assert planner.segment_at(3).uuid == "a", "à l'UI de demander, pas au planner de taire"


def test_disabled_segment_is_not_proposed_again():
    seg = Segment(0, 12, "music_offtopic", "a")
    planner = SkipPlanner([seg], {"music_offtopic": SKIP})
    assert planner.segment_at(5) is not None
    planner.disable(seg)
    assert planner.segment_at(5) is None, "l'annulation de l'utilisateur tient"


def test_target_chains_adjacent_segments():
    planner = SkipPlanner(
        [Segment(0, 10, "intro", "a"), Segment(10, 25, "sponsor", "b"),
         Segment(40, 50, "outro", "c")],
        {"intro": SKIP, "sponsor": SKIP, "outro": SKIP},
    )
    seg = planner.segment_at(2)
    assert planner.target_for(seg) == 25, "deux segments collés = un seul saut"


def test_target_is_clamped_to_duration():
    planner = SkipPlanner([Segment(170, 400, "outro", "a")], {"outro": SKIP})
    assert planner.target_for(planner.segment_at(180), duration=180.0) == 180.0


def test_target_does_not_chain_through_ignored_category():
    planner = SkipPlanner(
        [Segment(0, 10, "intro", "a"), Segment(10, 25, "filler", "b")],
        {"intro": SKIP, "filler": IGNORE},
    )
    assert planner.target_for(planner.segment_at(1)) == 10


def test_fetch_returns_empty_on_404(monkeypatch):
    def fake_urlopen(*_args, **_kwargs):
        raise urllib.error.HTTPError("url", 404, "Not Found", {}, None)

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)
    assert SponsorBlockClient().fetch(VIDEO, ["sponsor"]) == []


def test_fetch_sends_hash_prefix_not_video_id(monkeypatch):
    captured = {}

    class FakeResponse(io.BytesIO):
        def __enter__(self): return self
        def __exit__(self, *_): return False

    def fake_urlopen(request, **_kwargs):
        captured["url"] = request.full_url
        return FakeResponse(json.dumps(
            [{"videoID": VIDEO, "segments": [
                {"segment": [0, 9], "category": "music_offtopic", "UUID": "u"}]}]
        ).encode())

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)
    segments = SponsorBlockClient().fetch(VIDEO, ["music_offtopic"])

    assert VIDEO not in captured["url"], "l'ID de vidéo ne doit jamais partir en clair"
    assert f"/{video_hash_prefix(VIDEO)}?" in captured["url"]
    assert len(segments) == 1


def test_segments_for_never_raises_when_api_is_down(monkeypatch):
    monkeypatch.setattr("urllib.request.urlopen",
                        lambda *a, **k: (_ for _ in ()).throw(urllib.error.URLError("down")))
    assert SponsorBlockClient().segments_for(VIDEO, ["sponsor"]) == []


def test_cache_is_used_before_the_network(tmp_path, monkeypatch):
    from triat.core.library import Library

    lib = Library(tmp_path / "t.db")
    lib.cache_segments(VIDEO, [Segment(0, 15, "music_offtopic", "cached")])

    def explode(*_a, **_k):
        raise AssertionError("le réseau ne doit pas être touché quand le cache est chaud")

    monkeypatch.setattr("urllib.request.urlopen", explode)
    segments = SponsorBlockClient(lib).segments_for(VIDEO, ["music_offtopic"], 200.0)
    assert [s.uuid for s in segments] == ["cached"]
    lib.close()


@pytest.mark.network
def test_real_api_roundtrip():
    """Contrat réel avec sponsor.ajay.app (nécessite le réseau)."""
    client = SponsorBlockClient()
    segments = client.fetch("kJQP7kiw5Fk", ["music_offtopic", "sponsor", "outro"])
    assert isinstance(segments, list)
    for seg in segments:
        assert seg.end > seg.start

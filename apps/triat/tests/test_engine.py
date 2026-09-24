"""Tests d'orchestration : enchaînement, SponsorBlock, historique, reprise.

L'Engine fait son travail dans des threads et republie via GLib.idle_add :
les tests font donc tourner une vraie boucle d'événements GLib.
"""

from __future__ import annotations

import time

import pytest
from gi.repository import GLib

from triat.core.engine import Engine
from triat.core.library import Library
from triat.core.models import Segment, TrackRef
from triat.core.settings import Settings
from triat.core.sponsorblock import ASK, IGNORE, SKIP
from tests.fakes import FakeExtractor, FakePlayer, FakeRecommender, FakeSponsorBlock


def pump(condition=None, timeout: float = 2.0) -> bool:
    """Fait tourner la boucle GLib jusqu'à `condition` ou expiration."""
    context = GLib.MainContext.default()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        while context.pending():
            context.iteration(False)
        if condition is None:
            return True
        if condition():
            return True
        time.sleep(0.005)
    return condition() if condition else True


def refs(n: int) -> list[TrackRef]:
    return [TrackRef(f"v{i}", f"Titre {i}", "Artiste", 200.0) for i in range(n)]


@pytest.fixture
def engine(tmp_path):
    settings = Settings(tmp_path / "settings.json")
    settings.set("autoplay_radio", False)
    eng = Engine(
        settings=settings,
        library=Library(tmp_path / "lib.db"),
        player=FakePlayer(),
        extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(),
        recommender=FakeRecommender(),
        ytmusic=object(),
        cookies=object(),
    )
    yield eng
    eng.library.close()


# ---- Enchaînement -------------------------------------------------------

def test_playing_a_queue_resolves_and_starts_the_first_track(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    assert engine.player.played[0].video_id == "v0"
    assert engine.current.video_id == "v0"


def test_end_of_track_advances_to_the_next(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    engine.player.finish()
    assert pump(lambda: len(engine.player.played) == 2)
    assert engine.player.played[1].video_id == "v1"


def test_end_of_last_track_stops_when_autoplay_is_off(engine):
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.player.finish()
    pump(timeout=0.3)
    assert len(engine.player.played) == 1


def test_a_dead_track_does_not_block_the_queue(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", False)
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(fail_ids={"v0"}),
        sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
        ytmusic=object(), cookies=object(),
    )
    errors = []
    engine.connect("error", lambda _e, msg: errors.append(msg))
    engine.play_refs(refs(2))
    assert pump(lambda: engine.player.played, timeout=3.0)
    assert engine.player.played[0].video_id == "v1", "on saute la piste illisible"
    assert errors and "v0" in errors[0]
    engine.library.close()


def test_previous_rewinds_mid_track_instead_of_changing_track(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    engine.jump_to(1)
    assert pump(lambda: len(engine.player.played) == 2)
    engine.player.advance(60.0)
    engine.previous()
    assert engine.player.seeks[-1] == 0.0
    assert engine.current.video_id == "v1", "on reste sur la même piste"


def test_previous_at_the_very_start_goes_back_one_track(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    engine.jump_to(1)
    assert pump(lambda: len(engine.player.played) == 2)
    engine.player.advance(1.0)
    engine.previous()
    assert pump(lambda: engine.current.video_id == "v0")


# ---- SponsorBlock -------------------------------------------------------

def test_segment_is_skipped_automatically(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", False)
    settings.set("sponsorblock_categories", {"music_offtopic": SKIP})
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock([Segment(0, 22.0, "music_offtopic", "u1")]),
        recommender=FakeRecommender(), ytmusic=object(), cookies=object(),
    )
    skips = []
    engine.connect("segment-skipped", lambda _e, seg, gained: skips.append((seg, gained)))

    engine.play_refs(refs(1))
    assert pump(lambda: engine._planner is not None)
    engine.player.advance(1.0)
    pump(timeout=0.2)

    assert engine.player.seeks == [22.0]
    assert skips and skips[0][0].category == "music_offtopic"
    assert skips[0][1] == pytest.approx(21.0)
    assert engine.session_skips["segments"] == 1
    assert engine.session_skips["seconds"] == pytest.approx(21.0)
    assert len(engine.session_skips["tracks"]) == 1
    engine.library.close()


def test_same_segment_is_never_skipped_twice(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("sponsorblock_categories", {"sponsor": SKIP})
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock([Segment(10, 30, "sponsor", "u1")]),
        recommender=FakeRecommender(), ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(1))
    assert pump(lambda: engine._planner is not None)
    engine.player.advance(11.0)
    pump(timeout=0.1)
    # mpv renvoie souvent des positions antérieures juste après un seek.
    engine.player.advance(12.0)
    engine.player.advance(15.0)
    pump(timeout=0.2)
    assert engine.player.seeks == [30.0], "un seul saut malgré le retour en arrière"
    engine.library.close()


def test_ask_policy_notifies_instead_of_skipping(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("sponsorblock_categories", {"intro": ASK})
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock([Segment(0, 10, "intro", "u1")]),
        recommender=FakeRecommender(), ytmusic=object(), cookies=object(),
    )
    pending = []
    engine.connect("segment-pending", lambda _e, seg: pending.append(seg))
    engine.play_refs(refs(1))
    assert pump(lambda: engine._planner is not None)
    engine.player.advance(2.0)
    engine.player.advance(3.0)
    pump(timeout=0.2)
    assert engine.player.seeks == [], "rien n'est sauté sans accord"
    assert len(pending) == 1, "on ne redemande pas à chaque tick"
    engine.library.close()


def test_cancelling_a_skip_rewinds_and_disables_it(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("sponsorblock_categories", {"sponsor": SKIP})
    segment = Segment(10, 30, "sponsor", "u1")
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock([segment]),
        recommender=FakeRecommender(), ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(1))
    assert pump(lambda: engine._planner is not None)
    engine.player.advance(11.0)
    pump(timeout=0.1)

    engine.cancel_segment(segment)
    assert engine.player.seeks[-1] == 10.0
    engine.player.advance(11.0)
    pump(timeout=0.2)
    assert engine.player.seeks[-1] == 10.0, "après annulation, plus aucun saut"
    engine.library.close()


def test_sponsorblock_disabled_means_no_network_call(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("sponsorblock_enabled", False)
    sb = FakeSponsorBlock([Segment(0, 20, "sponsor", "u")])
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(), sponsorblock=sb,
        recommender=FakeRecommender(), ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    pump(timeout=0.3)
    assert sb.calls == []
    engine.library.close()


# ---- Historique ---------------------------------------------------------

def test_history_records_a_track_listened_long_enough(engine):
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.player.advance(150.0)          # 200 s au total, ratio 0.5
    engine.player.finish()
    pump(timeout=0.3)
    assert engine.library.stats()["plays"] == 1


def test_history_ignores_a_track_barely_started(engine):
    engine.play_refs(refs(2))
    assert pump(lambda: engine.player.played)
    engine.player.advance(4.0)
    engine.next()
    pump(timeout=0.3)
    assert engine.library.stats()["plays"] == 0


def test_private_session_writes_no_history(engine):
    engine.settings.set("private_session", True)
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.player.advance(180.0)
    engine.player.finish()
    pump(timeout=0.3)
    assert engine.library.stats()["plays"] == 0


def test_a_track_is_recorded_only_once(engine):
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.player.advance(180.0)
    engine.player.finish()
    engine._flush_history(completed=True)
    pump(timeout=0.3)
    assert engine.library.stats()["plays"] == 1


# ---- Radio automatique --------------------------------------------------

def test_autoplay_refills_the_queue_at_the_end(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", True)
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(),
        recommender=FakeRecommender(radio=[TrackRef("r1", "Radio 1"),
                                           TrackRef("r2", "Radio 2")]),
        ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.player.finish()
    assert pump(lambda: len(engine.queue) == 3, timeout=3.0)
    assert pump(lambda: engine.current.video_id == "r1", timeout=3.0)
    engine.library.close()


def test_autoplay_does_not_repeat_tracks_already_queued(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", True)
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(),
        recommender=FakeRecommender(radio=[TrackRef("v0", "Déjà là"),
                                           TrackRef("neuf", "Neuf")]),
        ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(1))          # contient déjà v0
    assert pump(lambda: engine.player.played)
    engine.player.finish()
    assert pump(lambda: len(engine.queue) == 2, timeout=3.0)
    assert [t.video_id for t in engine.queue.items] == ["v0", "neuf"]
    engine.library.close()


# ---- Persistance --------------------------------------------------------

def test_state_survives_a_restart(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", False)
    engine = Engine(
        settings=settings, library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
        ytmusic=object(), cookies=object(),
    )
    engine.play_refs(refs(4))
    assert pump(lambda: engine.player.played)
    engine.jump_to(2)
    assert pump(lambda: len(engine.player.played) == 2)
    engine.player.advance(75.0)
    engine.save_state()
    engine.library.close()

    revived = Engine(
        settings=Settings(tmp_path / "s.json"), library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
        ytmusic=object(), cookies=object(),
    )
    assert revived.restore_state() is True
    assert len(revived.queue) == 4
    assert revived.current.video_id == "v2"
    assert revived.player.played == [], "restaurer ne lance pas la lecture"
    revived.library.close()


def test_restore_on_a_fresh_profile_returns_false(tmp_path):
    engine = Engine(
        settings=Settings(tmp_path / "s.json"), library=Library(tmp_path / "l.db"),
        player=FakePlayer(), extractor=FakeExtractor(),
        sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
        ytmusic=object(), cookies=object(),
    )
    assert engine.restore_state() is False
    engine.library.close()


# ---- Préchargement --------------------------------------------------------

def test_next_track_is_resolved_in_advance(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    # Le préchargement part 3 s après le démarrage : on le déclenche.
    engine._prefetch_next()
    assert pump(lambda: engine._prefetched is not None, timeout=3.0)
    assert engine._prefetched[0] == "v1"


def test_prefetched_track_is_used_without_a_second_resolution(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    engine._prefetch_next()
    assert pump(lambda: engine._prefetched is not None, timeout=3.0)

    before = len(engine.extractor.resolved)
    engine.player.finish()
    assert pump(lambda: len(engine.player.played) == 2, timeout=3.0)
    assert len(engine.extractor.resolved) == before, \
        "la piste anticipée ne doit pas être résolue une seconde fois"


def test_prefetch_is_dropped_when_the_queue_changes(engine):
    engine.play_refs(refs(3))
    assert pump(lambda: engine.player.played)
    engine._prefetch_next()
    assert pump(lambda: engine._prefetched is not None, timeout=3.0)

    engine.queue.insert_next([TrackRef("neuf", "Neuf")])
    pump(timeout=0.3)
    assert engine._prefetched is None, "l'anticipation ne vaut plus"


def test_prefetch_does_nothing_on_an_empty_queue(engine):
    engine._prefetch_next()
    pump(timeout=0.3)
    assert engine._prefetched is None


def test_normalisation_setting_reaches_the_player(engine):
    engine.set_normalisation(False)
    assert engine.player.normalisation is False
    assert engine.settings.get("normalise_volume") is False


def test_equalizer_is_off_by_default(engine):
    assert engine.equalizer == (False, (0.0,) * 10)
    assert engine.player.equalizer is None


def test_equalizer_setting_reaches_the_player(engine):
    gains = (6, 5, 4, 2, 0, 0, 0, 0, 0, 0)
    engine.set_equalizer(enabled=True, gains=gains)
    assert engine.player.equalizer == tuple(float(g) for g in gains)
    assert engine.settings.get("eq_enabled") is True
    engine.set_equalizer(enabled=False)
    assert engine.player.equalizer is None
    # Les gains survivent à la désactivation.
    assert engine.equalizer[1][0] == 6.0


# ---- Clip vidéo (Immersion) ---------------------------------------------

def test_video_mode_grafts_the_clip_on_the_current_track(engine):
    engine.play_refs(refs(2))
    assert pump(lambda: engine.player.played)
    states = []
    engine.connect("video-changed", lambda _e, s, _v: states.append(s))
    engine.set_video_mode(True)
    assert pump(lambda: engine.player.video is not None)
    assert engine.player.video[0] == "v0"
    assert states == ["loading", "ready"]
    # Qualité « haute » par défaut → 1080p au plus.
    assert engine.extractor.video_heights == [1080]


def test_video_follows_the_next_track(engine):
    engine.play_refs(refs(2))
    assert pump(lambda: engine.player.played)
    engine.set_video_mode(True)
    assert pump(lambda: engine.player.video is not None)
    engine.next()
    assert pump(lambda: engine.player.video and engine.player.video[0] == "v1")


def test_leaving_video_mode_drops_the_clip(engine):
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.set_video_mode(True)
    assert pump(lambda: engine.player.video is not None)
    engine.set_video_mode(False)
    assert engine.player.video is None
    assert engine.video_state == "off"


def test_missing_clip_is_reported_but_audio_goes_on(engine):
    engine.extractor.no_video_ids.add("v0")
    engine.play_refs(refs(1))
    assert pump(lambda: engine.player.played)
    engine.set_video_mode(True)
    assert pump(lambda: engine.video_state == "unavailable")
    assert engine.player.video is None
    assert engine.player.state == "playing"


def test_late_clip_of_a_skipped_track_is_ignored(engine):
    engine.play_refs(refs(2))
    assert pump(lambda: engine.player.played)
    engine.set_video_mode(True)
    engine.next()                   # avant que le clip de v0 n'arrive
    assert pump(lambda: engine.player.video is not None)
    pump(timeout=0.2)
    assert engine.player.video[0] == "v1"


def test_backfill_fills_missing_durations(tmp_path):
    import time as _time
    from gi.repository import GLib
    from tests.fakes import (FakeCookies, FakeExtractor, FakeInnerTube,
                             FakePlayer, FakeRecommender, FakeSponsorBlock)
    from triat.core.engine import Engine
    from triat.core.library import Library
    from triat.core.models import TrackRef
    from triat.core.settings import Settings

    inner = FakeInnerTube()
    inner.lengths = {"a" * 11: 200.0}
    eng = Engine(settings=Settings(tmp_path / "s.json"),
                 library=Library(tmp_path / "l.db"), player=FakePlayer(),
                 extractor=FakeExtractor(), sponsorblock=FakeSponsorBlock(),
                 recommender=FakeRecommender(), ytmusic=object(),
                 cookies=FakeCookies(), innertube=inner)
    eng.library.upsert_many([TrackRef("a" * 11, "A"), TrackRef("b" * 11, "B")])
    changed = []
    eng.connect("library-changed", lambda *_: changed.append(1))
    eng.backfill_durations_async()
    deadline = _time.time() + 5
    while not changed and _time.time() < deadline:
        GLib.MainContext.default().iteration(False)
    assert changed
    assert eng.library.get_track("a" * 11).duration == 200.0
    assert eng.library.missing_duration() == ["b" * 11]
    # L'échec n'est pas réessayé dans la session.
    eng.backfill_durations_async()
    assert not eng._backfilling
    eng.library.close()


def test_play_after_restart_opens_the_restored_track(tmp_path):
    settings = Settings(tmp_path / "s.json")
    settings.set("autoplay_radio", False)
    engine = Engine(settings=settings, library=Library(tmp_path / "l.db"),
                    player=FakePlayer(), extractor=FakeExtractor(),
                    sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
                    ytmusic=object(), cookies=object())
    engine.play_refs(refs(3), start=1)
    pump(lambda: engine.player.played)
    engine.save_state()
    engine.library.close()

    revived = Engine(settings=settings, library=Library(tmp_path / "l.db"),
                     player=FakePlayer(), extractor=FakeExtractor(),
                     sponsorblock=FakeSponsorBlock(), recommender=FakeRecommender(),
                     ytmusic=object(), cookies=object())
    assert revived.restore_state()
    assert not revived.player.played
    revived.toggle_pause()                       # « lecture » après redémarrage
    assert pump(lambda: revived.player.played)
    revived.library.close()

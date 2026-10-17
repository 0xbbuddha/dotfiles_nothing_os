"""Tests de la file d'attente : ordre, aléatoire, répétition, mutations."""

import pytest

from triat.core.models import TrackRef
from triat.core.queue import REPEAT_ALL, REPEAT_OFF, REPEAT_ONE, Queue


def refs(n: int) -> list[TrackRef]:
    return [TrackRef(video_id=f"id{i}", title=f"T{i}") for i in range(n)]


@pytest.fixture
def q() -> Queue:
    queue = Queue()
    queue.set_items(refs(5))
    return queue


def ids(items) -> list[str]:
    return [t.video_id for t in items]


def test_empty_queue_is_inert():
    q = Queue()
    assert q.current is None
    assert q.next() is None
    assert q.previous() is None
    assert not q.has_next and not q.has_previous


def test_linear_playback(q):
    assert q.current.video_id == "id0"
    assert [q.next().video_id for _ in range(4)] == ["id1", "id2", "id3", "id4"]
    assert q.next() is None, "sans répétition, la file s'arrête à la fin"


def test_previous_stops_at_start(q):
    assert q.previous() is None
    q.next()
    assert q.previous().video_id == "id0"


def test_repeat_all_wraps_both_ways(q):
    q.repeat = REPEAT_ALL
    q.jump_to(4)
    assert q.next().video_id == "id0"
    assert q.previous().video_id == "id4"


def test_repeat_one_holds_but_manual_advances(q):
    q.repeat = REPEAT_ONE
    q.next()
    assert q.current.video_id == "id0", "la lecture auto rejoue la même piste"
    assert q.next(manual=True).video_id == "id1", "un clic Suivant doit avancer"


def test_start_index_is_respected():
    q = Queue()
    q.set_items(refs(5), start=3)
    assert q.current.video_id == "id3"
    assert ids(q.upcoming) == ["id4"]


def test_shuffle_plays_every_track_exactly_once():
    q = Queue()
    q.shuffle = True
    q.set_items(refs(20), start=7)
    assert q.current.video_id == "id7", "la piste choisie reste en tête"
    played = [q.current.video_id]
    while (nxt := q.next()) is not None:
        played.append(nxt.video_id)
    assert len(played) == 20
    assert len(set(played)) == 20, "aucune répétition ni omission"


def test_toggling_shuffle_keeps_current_track(q):
    q.jump_to(2)
    q.shuffle = True
    assert q.current.video_id == "id2"
    q.shuffle = False
    assert q.current.video_id == "id2"


def test_insert_next_jumps_the_line(q):
    q.jump_to(1)
    q.insert_next([TrackRef("vip", "Prioritaire")])
    assert ids(q.upcoming)[0] == "vip"
    assert q.next().video_id == "vip"


def test_append_on_empty_queue_selects_first():
    q = Queue()
    q.append(refs(3))
    assert q.current.video_id == "id0"


def test_remove_before_current_keeps_current(q):
    q.jump_to(3)
    q.remove_at(0)
    assert q.current.video_id == "id3"
    assert len(q) == 4


def test_remove_current_moves_to_next_in_order(q):
    q.jump_to(2)
    q.remove_at(2)
    assert len(q) == 4
    assert q.current.video_id == "id3", "la place libérée est prise par la suivante"


def test_remove_last_remaining_empties_queue():
    q = Queue()
    q.set_items(refs(1))
    q.remove_at(0)
    assert len(q) == 0 and q.current is None


def test_move_preserves_current_track(q):
    q.jump_to(1)
    current = q.current.video_id
    q.move(4, 0)
    assert q.current.video_id == current
    assert ids(q.items) == ["id4", "id0", "id1", "id2", "id3"]


def test_move_the_current_track_itself(q):
    q.jump_to(0)
    q.move(0, 3)
    assert q.current.video_id == "id0"
    assert ids(q.items) == ["id1", "id2", "id3", "id0", "id4"]


def test_snapshot_roundtrip_restores_position_and_modes(q):
    q.repeat = REPEAT_ALL
    q.jump_to(3)
    snap = q.snapshot()

    restored = Queue()
    restored.restore(snap)
    assert restored.current.video_id == "id3"
    assert restored.repeat == REPEAT_ALL
    assert ids(restored.items) == ids(q.items)


def test_restore_ignores_corrupt_entries():
    q = Queue()
    q.restore({"items": [{"video_id": "ok", "title": "T"}, {"title": "sans id"}, "nawak"],
               "index": 0, "repeat": "n'importe quoi"})
    assert ids(q.items) == ["ok"]
    assert q.repeat == REPEAT_OFF, "un mode inconnu retombe sur off"


def test_signals_fire_on_track_change(q):
    seen = []
    q.connect("current-changed", lambda _q, track: seen.append(track))
    q.next()
    assert seen and seen[-1].video_id == "id1"


def test_remove_current_when_it_is_last(q):
    q.jump_to(4)
    q.remove_at(4)
    assert q.current.video_id == "id3", "on recule sur la dernière piste restante"


def test_remove_after_current_keeps_current(q):
    q.jump_to(1)
    q.remove_at(4)
    assert q.current.video_id == "id1"
    assert len(q) == 4


def test_remove_under_shuffle_keeps_current():
    q = Queue()
    q.shuffle = True
    q.set_items(refs(10), start=0)
    current = q.current.video_id
    # Retire une piste qui n'est pas la courante, quelle que soit sa place
    # dans l'ordre mélangé.
    victim = next(i for i, t in enumerate(q.items) if t.video_id != current)
    q.remove_at(victim)
    assert q.current.video_id == current
    remaining = [q.current.video_id]
    while (nxt := q.next()) is not None:
        remaining.append(nxt.video_id)
    assert len(remaining) == 9 and len(set(remaining)) == 9

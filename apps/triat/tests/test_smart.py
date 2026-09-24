"""Smart playlists (core/smart.py)."""

from __future__ import annotations

import time

from triat.core.library import Library
from triat.core.models import TrackRef
from triat.core.smart import DAY, smart_playlists


def ref(i: int) -> TrackRef:
    return TrackRef(f"{i:011d}", f"T{i}", "A", 100.0)


class Downloads:
    def __init__(self, ids):
        self.ids = set(ids)

    def local_path(self, r):
        return "/x" if r.video_id in self.ids else None


def test_rules(tmp_path):
    lib = Library(tmp_path / "l.db")
    lib.upsert_many([ref(1), ref(2), ref(3), ref(4)])
    pid = lib.create_playlist("P")
    lib.add_to_playlist(pid, [ref(2), ref(3)])
    lib.record_play(ref(1), 90, True)
    # ref(4) : simple résultat de recherche mis en cache, pas à l'utilisateur.
    with lib._lock:
        lib._db.execute("UPDATE tracks SET added_at = ? WHERE video_id = ?",
                        (time.time() - 40 * DAY, ref(3).video_id))
    smart = {s.key: s for s in smart_playlists(lib, Downloads([ref(2).video_id]))}
    ids = lambda key: [r.video_id for r in smart[key].fetch()]
    assert ids("repeat") == [ref(1).video_id]
    assert set(ids("unplayed")) == {ref(2).video_id, ref(3).video_id}
    assert set(ids("recent")) == {ref(1).video_id, ref(2).video_id}
    assert ids("offline") == [ref(2).video_id]
    lib.close()


def test_offline_without_downloads(tmp_path):
    lib = Library(tmp_path / "l.db")
    assert [s.key for s in smart_playlists(lib)] == ["repeat", "unplayed", "recent", "offline"]
    assert smart_playlists(lib)[3].fetch() == []
    lib.close()

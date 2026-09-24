"""Tests du gestionnaire de téléchargements."""

from __future__ import annotations

import pytest

from triat.core import downloads as dl
from triat.core.downloads import (CANCELLED, DONE, PENDING, DownloadManager,
                                  Task, safe_name)
from triat.core.models import TrackRef
from triat.core.settings import Settings


@pytest.mark.parametrize("value,expected", [
    ("AC/DC", "ACDC"),
    ("Fichier: test?", "Fichier test"),
    ("a<b>c|d", "abcd"),
    ("  ..cache  ", "cache"),
    ("", "Inconnu"),
    ("nom\x00nul", "nomnul"),
])
def test_filenames_are_sanitised(value, expected):
    assert safe_name(value) == expected


def test_filenames_are_capped():
    assert len(safe_name("a" * 200)) <= 80


def test_no_path_traversal_survives():
    """Un titre hostile ne doit pas sortir du dossier de destination."""
    assert "/" not in safe_name("../../etc/passwd")
    assert ".." not in safe_name("..")


@pytest.fixture
def manager(tmp_path, monkeypatch):
    monkeypatch.setattr(dl, "downloads_dir", lambda: tmp_path)
    settings = Settings(tmp_path / "s.json")
    return DownloadManager(settings=settings)


def test_target_uses_artist_and_album(manager, tmp_path):
    ref = TrackRef("a" * 11, "Titre", "Artiste", album="Album")
    assert manager.target_dir(ref) == tmp_path / "Artiste" / "Album"


def test_target_without_album(manager, tmp_path):
    ref = TrackRef("a" * 11, "Titre", "Artiste")
    assert manager.target_dir(ref) == tmp_path / "Artiste"


def test_unknown_artist_has_a_folder(manager, tmp_path):
    assert manager.target_dir(TrackRef("a" * 11, "T")) == \
        tmp_path / "Artiste inconnu"


def test_local_path_finds_an_existing_file(manager, tmp_path):
    ref = TrackRef("a" * 11, "Ma Piste", "Artiste")
    folder = tmp_path / "Artiste"
    folder.mkdir(parents=True)
    (folder / "Ma Piste.opus").write_bytes(b"audio")
    assert manager.local_path(ref) is not None


def test_local_path_ignores_empty_files(manager, tmp_path):
    ref = TrackRef("a" * 11, "Vide", "Artiste")
    folder = tmp_path / "Artiste"
    folder.mkdir(parents=True)
    (folder / "Vide.opus").write_bytes(b"")
    assert manager.local_path(ref) is None


def test_queue_refuses_duplicates(manager):
    refs = [TrackRef("b" * 11, "B", "A")]
    assert manager.add(refs) == 1
    assert manager.add(refs) == 0, "déjà dans la file"


def test_queue_skips_already_downloaded(manager, tmp_path):
    ref = TrackRef("c" * 11, "Faite", "Artiste")
    folder = tmp_path / "Artiste"
    folder.mkdir(parents=True)
    (folder / "Faite.m4a").write_bytes(b"audio")
    assert manager.add([ref]) == 0


def test_cancel_marks_a_pending_task(manager):
    manager.pause()          # empêche le worker de la prendre
    manager.add([TrackRef("d" * 11, "D", "A")])
    manager.cancel("d" * 11)
    assert manager.tasks[0].state == CANCELLED


def test_clear_finished_keeps_pending(manager):
    manager.pause()
    manager.add([TrackRef("e" * 11, "E", "A"), TrackRef("f" * 11, "F", "A")])
    manager.tasks[0].state = DONE
    task_states = {t.ref.video_id: t for t in manager.tasks}
    task_states["e" * 11].state = DONE
    manager.clear_finished()
    assert all(t.state == PENDING for t in manager.tasks)


def test_options_never_use_an_external_downloader(manager):
    """CVE-2026-50019 : curl en téléchargeur externe fuite les cookies."""
    options = manager._options(Task(ref=TrackRef("g" * 11, "G", "A")))
    assert options.get("external_downloader") is None


def test_sponsorblock_cut_is_configurable(manager):
    task = Task(ref=TrackRef("h" * 11, "H", "A"))
    keys = [p["key"] for p in manager._options(task)["postprocessors"]]
    assert "SponsorBlock" in keys and "ModifyChapters" in keys

    manager._settings.set("download_cut_sponsorblock", False)
    keys = [p["key"] for p in manager._options(task)["postprocessors"]]
    assert "SponsorBlock" not in keys


def test_format_selection(manager):
    task = Task(ref=TrackRef("i" * 11, "I", "A"))
    manager._settings.set("download_format", "mp3")
    options = manager._options(task)
    codec = next(p["preferredcodec"] for p in options["postprocessors"]
                 if p["key"] == "FFmpegExtractAudio")
    assert codec == "mp3"


def test_download_is_silent(manager):
    """yt-dlp ne doit rien écrire sur la sortie standard."""
    options = manager._options(Task(ref=TrackRef("j" * 11, "J", "A")))
    assert options.get("quiet") is True
    assert options.get("noprogress") is True

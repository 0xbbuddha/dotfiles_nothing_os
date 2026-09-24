"""Égaliseur : validation des gains, graphe de filtres, branchement."""

from __future__ import annotations

import math

import pytest

from triat.core.equalizer import (BANDS, CUSTOM, FLAT, PRESETS, build_filter,
                                  clamp_gains, match_preset, preset_gains)


def test_flat_builds_no_filter():
    assert build_filter(FLAT) == ""


def test_boost_adds_headroom_and_skips_zero_bands():
    gains = (6, 0, 0, 0, 0, 0, 0, 0, 0, -3)
    graph = build_filter(gains)
    assert graph.startswith("lavfi=[volume=-6dB,")
    assert "f=31:" in graph and "g=6" in graph
    assert "f=16000:" in graph and "g=-3" in graph
    assert "f=62:" not in graph


def test_cut_only_needs_no_headroom():
    assert "volume" not in build_filter((-4,) + (0,) * 9)


@pytest.mark.parametrize("bad", [None, "6,6", [1] * 9, [1] * 11,
                                 [0] * 9 + ["x"], [0] * 9 + [math.nan],
                                 [0] * 9 + [True]])
def test_invalid_gains_fall_back_to_flat(bad):
    assert clamp_gains(bad) == FLAT


def test_gains_are_clamped():
    assert clamp_gains([99] + [-99] + [0] * 8)[:2] == (12.0, -12.0)


def test_presets_are_well_formed_and_recognised():
    for pid, _label, gains in PRESETS:
        assert len(gains) == len(BANDS)
        assert preset_gains(pid) == clamp_gains(gains)
        assert match_preset(gains) == pid
    assert match_preset((1,) * 10) == CUSTOM


def test_filter_graph_is_accepted_by_mpv():
    """Le graphe doit passer tel quel dans libmpv, sinon rien ne s'applique."""
    mpv = pytest.importorskip("mpv")
    player = mpv.MPV(video=False, audio_display="no", idle=True,
                     terminal=False, ao="null")
    try:
        graph = build_filter(preset_gains("rock"))
        player.af = graph + ",dynaudnorm=g=5:f=250:r=0.9:p=0.5"
        assert "equalizer" in str(player.af)
    finally:
        player.terminate()

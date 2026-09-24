from triat.core.spectrum import BARS, parse_frame


def test_parse_full_frame():
    line = ";".join(["50"] * BARS) + ";\n"
    assert parse_frame(line) == [0.5] * BARS


def test_partial_or_garbage_frames_are_dropped():
    assert parse_frame("1;2;3;\n") is None
    assert parse_frame(";".join(["x"] * BARS)) is None


def test_values_are_clamped():
    assert parse_frame(";".join(["250"] * BARS))[0] == 1.0

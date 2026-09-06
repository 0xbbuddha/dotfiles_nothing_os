#!/usr/bin/env bash
# Rebuild the fastfetch dot-matrix logos in config/fastfetch/logos/.
#
# They are derived art, not hand-drawn: the Arch mountain comes from
# /usr/share/pixmaps/archlinux-logo.svg and the Nothing mark from the
# vector already in the shell (components/NothingIcons.qml), so both are
# the real shapes rather than an approximation of them. Run this if
# either source changes.
#
# Downsampling uses -filter Box, which averages the area a dot covers.
# Lanczos was tried first and rings: it overshoots at every hard edge and
# scatters lit dots into the empty margin around the shape.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$ROOT/scripts/make-fetch-logos.py" "$ROOT"

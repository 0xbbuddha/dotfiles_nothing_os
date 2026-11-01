#!/usr/bin/env bash
# Move every currently playing PipeWire sink-input onto $1 (a sink name
# or id). set-default only steers *new* streams, so this is what makes
# a stream already playing follow immediately on a sink change.
#
# Shared by Audio.qml's setSink() and bt-a2dp-fix.sh's route_audio():
# the same loop used to live independently in both, and had already
# drifted into two slightly different versions.
set -u
target="$1"
[[ -n "$target" ]] || exit 0
command -v pactl >/dev/null 2>&1 || exit 0
pactl list short sink-inputs 2>/dev/null | while read -r sinput _; do
    [[ "$sinput" =~ ^[0-9]+$ ]] || continue
    pactl move-sink-input "$sinput" "$target" >/dev/null 2>&1
done

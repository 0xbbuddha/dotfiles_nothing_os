#!/usr/bin/env bash
# Music recognition via songrec (free Shazam client).
# Listens to the system audio output, not the mic: we identify what the
# machine is playing.
#   songrec.sh [duration_in_seconds]
# Writes to stdout: "TITLE|ARTIST" or an error message.
set -uo pipefail

DURATION="${1:-16}"
TMP="$(mktemp -u /tmp/nothing-songrec-XXXXXX.wav)"
trap 'rm -f "$TMP"' EXIT

command -v songrec >/dev/null 2>&1 || { echo "songrec is not installed"; exit 1; }

# Monitor of the default output: what you hear.
SINK="$(pactl get-default-sink 2>/dev/null).monitor"
if [[ -z "$SINK" || "$SINK" == ".monitor" ]]; then
    echo "Audio output not found"; exit 1
fi

if ! timeout "$((DURATION + 4))" parec --device="$SINK" \
        --file-format=wav --format=s16le --rate=44100 --channels=1 \
        --latency-msec=100 "$TMP" 2>/dev/null; then
    :   # parec is stopped by the timeout; that is expected
fi

[[ -s "$TMP" ]] || { echo "No audio captured"; exit 1; }

OUT="$(songrec audio-file-to-recognized-song "$TMP" 2>/dev/null)" || {
    echo "Recognition failed"; exit 1; }

printf '%s' "$OUT" | jq -r '
    if .track then "\(.track.title)|\(.track.subtitle)"
    else "No match" end' 2>/dev/null || echo "No match"

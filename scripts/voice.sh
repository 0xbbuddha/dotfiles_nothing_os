#!/usr/bin/env bash
# Microphone voice note for the Essential Key.
# Runs in the foreground so Quickshell can stop it by killing the process.
#   voice.sh record   -> records until SIGTERM / SIGINT
#   voice.sh status
set -uo pipefail

LAST="${XDG_RUNTIME_DIR:-/tmp}/nothing-voice.last"
LOG="${XDG_RUNTIME_DIR:-/tmp}/nothing-voice.log"
OUT="${XDG_RUNTIME_DIR:-/tmp}/nothing-voice.oga"

case "${1:-status}" in
  status)
    if pgrep -x pw-record >/dev/null 2>&1 || pgrep -x parec >/dev/null 2>&1; then
        echo "recording"
    else
        echo "idle"
    fi
    ;;

  record)
    rm -f "$OUT"
    echo "$OUT" > "$LAST"
    : > "$LOG"

    if command -v pw-record >/dev/null 2>&1; then
        # Capture = microphone. Playback would tap the sink monitor.
        exec pw-record \
            --media-type Audio \
            --media-category Capture \
            --media-role Communication \
            --rate 16000 \
            --channels 1 \
            --format opus \
            --container oga \
            "$OUT" >"$LOG" 2>&1
    fi

    if command -v parec >/dev/null 2>&1; then
        OUT="${XDG_RUNTIME_DIR:-/tmp}/nothing-voice.wav"
        echo "$OUT" > "$LAST"
        exec parec --file-format=wav --format=s16le --rate=16000 --channels=1 \
            --latency-msec=100 "$OUT" >"$LOG" 2>&1
    fi

    echo "No recorder (pw-record or parec)" >&2
    exit 1
    ;;

  *)
    echo "usage: voice.sh record|status" >&2
    exit 2
    ;;
esac

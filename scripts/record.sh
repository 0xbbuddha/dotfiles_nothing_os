#!/usr/bin/env bash
# Screen recording. Like the ii script: a second call STOPS.
#   record.sh start [region|screen] [sound]
#   record.sh stop
#   record.sh status
set -uo pipefail

DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Captures"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.pid"
LASTFILE="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.last"
LOG="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.log"

running() {
    pgrep -x wf-recorder >/dev/null 2>&1 && return 0
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        return 0
    fi
    return 1
}

stop_rec() {
    if ! running; then
        rm -f "$PIDFILE"
        echo "No recording"
        exit 0
    fi
    [[ -f "$PIDFILE" ]] && kill -INT "$(cat "$PIDFILE")" 2>/dev/null || true
    pkill -INT -x wf-recorder 2>/dev/null || true
    for _ in $(seq 1 80); do
        pgrep -x wf-recorder >/dev/null 2>&1 || break
        sleep 0.1
    done
    pgrep -x wf-recorder >/dev/null 2>&1 && pkill -KILL -x wf-recorder 2>/dev/null || true
    rm -f "$PIDFILE"
    local name
    name="$(basename "$(cat "$LASTFILE" 2>/dev/null)" 2>/dev/null)"
    echo "Stopped${name:+ : $name}"
}

case "${1:-status}" in
  status)
    if running; then echo "recording"; else echo "idle"; fi
    ;;

  stop)
    stop_rec
    ;;

  start)
    # Second click = stop, like ii's record.sh.
    if running; then
        stop_rec
        exit 0
    fi
    command -v wf-recorder >/dev/null 2>&1 || { echo "wf-recorder is not installed"; exit 1; }

    MODE="${2:-screen}"
    SOUND="${3:-}"
    mkdir -p "$DIR"
    FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    echo "$FILE" > "$LASTFILE"

    ARGS=(-f "$FILE" --pixel-format yuv420p)

    # -o and -g together: wf-recorder ignores or rejects the selection.
    # ii only sets -o for fullscreen.
    if [[ "$MODE" == "region" ]]; then
        GEO="${4:-}"
        [[ -n "$GEO" ]] || { echo "No region"; exit 1; }
        ARGS+=(-g "$GEO")
    else
        MON="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null || true)"
        [[ -n "$MON" && "$MON" != "null" ]] && ARGS+=(-o "$MON")
    fi

    if [[ "$SOUND" == "sound" ]]; then
        SRC="$(pactl list sources 2>/dev/null | awk '/Name:/{print $2}' | grep monitor | head -n1 || true)"
        if [[ -n "$SRC" ]]; then
            ARGS+=(--audio="$SRC")
        else
            ARGS+=(--audio)
        fi
    fi

    # setsid: killing the Quickshell process must not kill wf-recorder.
    : > "$LOG"
    setsid -f wf-recorder "${ARGS[@]}" >"$LOG" 2>&1
    sleep 0.2
    pgrep -n -x wf-recorder > "$PIDFILE" 2>/dev/null || true
    sleep 0.2
    if running; then
        echo "Recording started"
    else
        rm -f "$PIDFILE"
        ERR="$(tr '\n' ' ' < "$LOG" 2>/dev/null | sed 's/[[:space:]]*$//')"
        echo "Failed to start${ERR:+ : $ERR}"
        exit 1
    fi
    ;;
esac

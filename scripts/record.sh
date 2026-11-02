#!/usr/bin/env bash
# Screen recording. Like the ii script: a second call STOPS.
#   record.sh start [region|screen] [none|sys|mic|both] [geo]
#   record.sh stop
#   record.sh status
#
# Audio token (3rd arg):
#   none  no audio
#   sys   system output (the default sink's monitor)
#   mic   the default input (microphone)
#   both  system + mic mixed into a throwaway null sink
#
# "both" is the only one that needs plumbing: wf-recorder takes a single
# --audio, so the two sources are loop-backed into one null sink and its
# monitor is recorded. The module ids go in MODFILE and are unloaded on
# stop, so nothing is left dangling if the recording ends any other way.
set -uo pipefail

# The shell launching this may not export XDG_VIDEOS_DIR (it lives in
# user-dirs.dirs, read by the login session, not by every child). Source
# it so the files land where the file manager's "Videos" actually points
# — on a French locale that is ~/Vidéos, not ~/Videos.
if [[ -z "${XDG_VIDEOS_DIR:-}" && -f "$HOME/.config/user-dirs.dirs" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.config/user-dirs.dirs" 2>/dev/null || true
fi
DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Captures"
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.pid"
LASTFILE="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.last"
MODFILE="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.mods"
LOG="${XDG_RUNTIME_DIR:-/tmp}/nothing-record.log"
MIXNAME="nothing_rec_mix"

running() {
    pgrep -x wf-recorder >/dev/null 2>&1 && return 0
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Tear down the combined null sink and its loopbacks, if any were made.
unload_mix() {
    if [[ -f "$MODFILE" ]]; then
        local id
        for id in $(cat "$MODFILE" 2>/dev/null); do
            pactl unload-module "$id" 2>/dev/null || true
        done
        rm -f "$MODFILE"
    fi
}

# Builds the combined-sink mix for "both" (system + mic). Echoes the
# --audio value to use: the mix monitor on success, a single source on
# any missing input or partial load failure - never claims "both" while
# actually recording less. Module ids land in MODFILE only on success.
mix_both() {
    local monsrc="$1" micsrc="$2"
    if [[ -z "$monsrc" || -z "$micsrc" ]]; then
        echo "${monsrc:-$micsrc}"
        return
    fi
    local mods=() id
    id="$(pactl load-module module-null-sink sink_name="$MIXNAME" \
            sink_properties=device.description="$MIXNAME" rate=48000 2>/dev/null || true)"
    [[ -n "$id" ]] && mods+=("$id")
    id="$(pactl load-module module-loopback source="$monsrc" sink="$MIXNAME" latency_msec=60 2>/dev/null || true)"
    [[ -n "$id" ]] && mods+=("$id")
    id="$(pactl load-module module-loopback source="$micsrc" sink="$MIXNAME" latency_msec=60 2>/dev/null || true)"
    [[ -n "$id" ]] && mods+=("$id")
    if [[ "${#mods[@]}" -eq 3 ]]; then
        printf '%s\n' "${mods[@]}" > "$MODFILE"
        echo "${MIXNAME}.monitor"
    else
        for id in "${mods[@]}"; do pactl unload-module "$id" 2>/dev/null || true; done
        echo "${monsrc:-$micsrc}"
    fi
}

sink_monitor() {
    local s
    s="$(pactl get-default-sink 2>/dev/null || true)"
    if [[ -n "$s" && "$s" != "null" ]]; then
        echo "${s}.monitor"
        return
    fi
    pactl list sources 2>/dev/null | awk '/Name:/{print $2}' | grep monitor | head -n1
}

default_source() {
    local s
    s="$(pactl get-default-source 2>/dev/null || true)"
    [[ -n "$s" && "$s" != "null" ]] && echo "$s"
}

stop_rec() {
    if ! running; then
        rm -f "$PIDFILE"
        unload_mix
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
    unload_mix
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
    AUDIO="${3:-none}"
    # Back-compat: the old caller passed the literal "sound" for system audio.
    [[ "$AUDIO" == "sound" ]] && AUDIO="sys"
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

    # A stale mix from a crashed run must not get in the way. Only our own
    # named sink and its loopbacks, never the user's other null sinks.
    unload_mix
    for id in $(pactl list modules short 2>/dev/null | grep -F "$MIXNAME" | awk '{print $1}'); do
        pactl unload-module "$id" 2>/dev/null || true
    done

    case "$AUDIO" in
      none)
        ;;
      sys)
        SRC="$(sink_monitor)"
        if [[ -n "$SRC" ]]; then ARGS+=(--audio="$SRC"); else ARGS+=(--audio); fi
        ;;
      mic)
        SRC="$(default_source)"
        if [[ -n "$SRC" ]]; then ARGS+=(--audio="$SRC"); else ARGS+=(--audio); fi
        ;;
      both)
        MONSRC="$(sink_monitor)"
        MICSRC="$(default_source)"
        SRC="$(mix_both "$MONSRC" "$MICSRC")"
        if [[ -n "$SRC" ]]; then ARGS+=(--audio="$SRC"); else ARGS+=(--audio); fi
        ;;
    esac

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
        unload_mix
        ERR="$(tr '\n' ' ' < "$LOG" 2>/dev/null | sed 's/[[:space:]]*$//')"
        echo "Failed to start${ERR:+ : $ERR}"
        exit 1
    fi
    ;;
esac

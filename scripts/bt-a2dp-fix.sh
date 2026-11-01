#!/usr/bin/env bash
# Brings a Bluetooth headset all the way to playing audio on connect.
#
# Two things go wrong between "Connected: yes" and sound coming out:
#
#   1. Some headsets (Nothing's included) only bring up the BLE/GATT link
#      on connect - enough for BlueZ to call the device Connected, but
#      PipeWire never sees a card because the classic A2DP transport was
#      never negotiated. The device stays silent until something calls
#      Device1.ConnectProfile() on the Audio Sink UUID by hand.
#
#   2. Even once the A2DP sink appears, the default sink and any stream
#      already playing stay on the laptop speakers - set-default only
#      steers *new* streams, so whatever is running keeps going out the
#      wrong hole and the headset sits there silent.
#
# So on every connect of an audio device we force the profile, wait for
# the PipeWire sink to show up, make it the default, and drag the running
# streams across to it.
set -u

command -v bluetoothctl >/dev/null 2>&1 || exit 0

# One only, same reasoning as bt-agent.sh: a lock rather than pgrep, which
# kept matching this very script and bailing.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nothing-bt-a2dp-fix.lock"
flock -n 9 || exit 0

AUDIO_SINK_UUID="0000110b-0000-1000-8000-00805f9b34fb"

have() { command -v "$1" >/dev/null 2>&1; }

# The PipeWire Audio/Sink node that belongs to a given MAC, printed as
# "<id>\t<node.name>", empty if PipeWire has no sink for it (yet). The
# address property keeps BlueZ's colon form; match case-insensitively
# since adapters differ on upper vs lower.
bt_sink_node() {
    have pw-dump && have jq || return 0
    pw-dump 2>/dev/null | jq -r --arg mac "$1" '
        .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Audio/Sink")
        | select((.info.props["api.bluez5.address"] // "" | ascii_downcase)
                 == ($mac | ascii_downcase))
        | "\(.id)\t\(.info.props["node.name"])"' 2>/dev/null | head -1
}

# Wait for the headset's sink to appear, make it default, and move every
# stream already playing onto it.
route_audio() {
    local mac="$1" row id name tries sinput
    # The sink lands a second or two after ConnectProfile returns; poll
    # for it rather than guessing a fixed sleep.
    for ((tries = 0; tries < 30; tries++)); do
        row="$(bt_sink_node "$mac")"
        [[ -n "$row" ]] && break
        sleep 0.5
    done
    [[ -n "$row" ]] || return 0

    id="${row%%$'\t'*}"
    name="${row#*$'\t'}"

    have wpctl && wpctl set-default "$id" >/dev/null 2>&1

    # set-default only redirects new streams; pull the playing ones over
    # by hand so music that was already going switches to the headset.
    if have pactl && [[ -n "$name" && "$name" != "null" ]]; then
        pactl list short sink-inputs 2>/dev/null | while read -r sinput _; do
            [[ "$sinput" =~ ^[0-9]+$ ]] || continue
            pactl move-sink-input "$sinput" "$name" >/dev/null 2>&1
        done
    fi
}

fix_profile() {
    local mac="$1" adapter dev_path uuids
    adapter="$(busctl tree org.bluez 2>/dev/null \
        | grep -o '/org/bluez/hci[0-9]*' | head -1)"
    [[ -n "$adapter" ]] || return 0
    dev_path="$adapter/dev_${mac//:/_}"

    # Only for gear that actually claims the Audio Sink service: calling
    # ConnectProfile on a mouse or a phone is a no-op at best, a spurious
    # pairing prompt on the other end at worst.
    uuids="$(busctl get-property org.bluez "$dev_path" \
        org.bluez.Device1 UUIDs 2>/dev/null)"
    [[ "$uuids" == *110b* ]] || return 0

    # BlueZ needs a moment after Connected to settle the ACL link before
    # a profile request lands cleanly. Harmless if A2DP is already up -
    # BlueZ just answers "already connected".
    sleep 2
    busctl call org.bluez "$dev_path" org.bluez.Device1 \
        ConnectProfile s "$AUDIO_SINK_UUID" >/dev/null 2>&1

    route_audio "$mac"
}

# A headset that auto-connected during boot - before this script, or
# before PipeWire - never emits a "Connected: yes" line for us to catch,
# so sweep the already-connected devices once at start. fix_profile
# re-checks the Audio Sink UUID, so handing it a stray device is safe.
scan_connected() {
    local line mac
    # `devices Connected` is the cheap path; older bluetoothctl lacks the
    # filter and lists everything, which fix_profile then filters anyway.
    bluetoothctl devices Connected 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" =~ ([0-9A-Fa-f:]{17}) ]]; then
            mac="${BASH_REMATCH[1]}"
            fix_profile "$mac" &
        fi
    done
}

scan_connected

# Restart if bluetoothctl dies, and ride out a bluetoothd restart. Same
# shape as bt-agent.sh: the pipe has to stay open, or bluetoothctl exits
# the moment stdin closes and there is nothing left to read events from.
while true; do
    { sleep infinity; } | bluetoothctl 2>/dev/null | while IFS= read -r line; do
        # Strip ANSI colour codes before matching: bluetoothctl paints
        # every line even when nothing is reading them as a terminal.
        plain="$(sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' <<<"$line")"
        if [[ "$plain" =~ Device\ ([0-9A-Fa-f:]{17})\ Connected:\ yes ]]; then
            fix_profile "${BASH_REMATCH[1]}" &
        fi
    done
    sleep 5
done

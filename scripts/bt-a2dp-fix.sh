#!/usr/bin/env bash
# Forces the A2DP audio profile the moment a Bluetooth headset connects.
#
# Some headsets (Nothing's included) only bring up the BLE/GATT link on
# connect - that is enough for BlueZ to call the device Connected, but
# PipeWire never sees a card because the classic A2DP transport was never
# negotiated. The device stays silent until something calls
# Device1.ConnectProfile() on the Audio Sink UUID by hand. Normally that is
# the "something": watch bluetoothctl's own event stream for "Connected:
# yes", check the device actually advertises Audio Sink, then place that
# call ourselves.
set -u

command -v bluetoothctl >/dev/null 2>&1 || exit 0

# One only, same reasoning as bt-agent.sh: a lock rather than pgrep, which
# kept matching this very script and bailing.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nothing-bt-a2dp-fix.lock"
flock -n 9 || exit 0

AUDIO_SINK_UUID="0000110b-0000-1000-8000-00805f9b34fb"

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
    # a profile request lands cleanly.
    sleep 2
    busctl call org.bluez "$dev_path" org.bluez.Device1 \
        ConnectProfile s "$AUDIO_SINK_UUID" >/dev/null 2>&1
}

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

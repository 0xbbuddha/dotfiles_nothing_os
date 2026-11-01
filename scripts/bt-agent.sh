#!/usr/bin/env bash
# Persistent BlueZ pairing agent.
#
# Quickshell registers none, and BlueZ refuses to complete a pairing
# without one: `device.pair()` fails in silence and `bluetoothctl pair`
# answers "not available". Desktops normally inherit this from blueman,
# or from KDE's bluedevil running inside kded; neither belongs in a rice
# this size, and bluetoothctl holds an agent itself for free.
#
# NoInputNoOutput accepts "just works" pairing, which is what speakers,
# headphones and most audio gear use. A device demanding a typed passkey
# still needs a full manager.
set -u

command -v bluetoothctl >/dev/null 2>&1 || exit 0

# One only: a second agent fights the first for the registration. A lock
# rather than pgrep, which kept matching this very script and bailing.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/nothing-bt-agent.lock"
flock -n 9 || exit 0

# Restart if bluetoothctl dies, and ride out a bluetoothd restart. The
# coprocess keeps stdin open, which bluetoothctl needs to keep its agent.
while true; do
    coproc AGENT { exec bluetoothctl >/dev/null 2>&1; }
    printf 'pairable off\nagent NoInputNoOutput\ndefault-agent\n' >&"${AGENT[1]}"
    wait "$AGENT_PID" 2>/dev/null
    sleep 5
done

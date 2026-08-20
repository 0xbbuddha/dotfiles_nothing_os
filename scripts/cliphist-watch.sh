#!/usr/bin/env bash
# Relay wl-paste --watch → cliphist. The type (text|image) is $1.
#
# Chromium/Helium copies sometimes arrive as UTF-16 (NUL between each
# letter). Store a stripped copy. Do NOT call wl-copy from here: we are
# already inside a wl-paste --watch handler, and rewriting the clipboard
# deadlocks the watcher so later copies never land in cliphist.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
kind="${1:-text}"

if [[ "$kind" == "text" ]]; then
    python3 -c '
import subprocess, sys
data = sys.stdin.buffer.read()
if b"\x00" in data:
    data = data.replace(b"\x00", b"")
if data:
    subprocess.run(["cliphist", "store"], input=data)
'
else
    cliphist store
fi

notify_shell() {
    local p
    for p in \
        "${HOME}/.config/quickshell/nothing" \
        "${ROOT}/quickshell/nothing"; do
        if [[ -f "${p}/shell.qml" ]]; then
            qs -p "$p" ipc call clipboard update >/dev/null 2>&1 && return 0
        fi
    done
    return 0
}
notify_shell

#!/usr/bin/env bash
# Start cliphist relays if they are not already running.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
WATCH="$ROOT/scripts/cliphist-watch.sh"
[[ -x "$WATCH" ]] || exit 0

if pgrep -x wl-paste >/dev/null; then
    exit 0
fi

wl-paste --type text --watch "$WATCH" text &
wl-paste --type image --watch "$WATCH" image &
disown || true

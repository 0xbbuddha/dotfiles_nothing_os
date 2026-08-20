#!/usr/bin/env bash
# Run ONLY the "Nothing" Quickshell shell on top of the current session.
# Handy for iterating quickly on QML (hot reload included).
#
#   ./scripts/run-shell.sh          → foreground, Ctrl-C to stop
#   ./scripts/run-shell.sh --solo   → pause your current shell (illogical-impulse)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOLO=0
[[ "${1:-}" == "--solo" ]] && SOLO=1

cleanup() {
    if [[ $SOLO -eq 1 ]]; then
        echo "→ Restarting your usual shell…"
        qs -c ii -d >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if [[ $SOLO -eq 1 ]]; then
    echo "→ Temporarily stopping the 'ii' shell…"
    pkill -f 'quickshell.*-c ii' 2>/dev/null || true
    pkill -f 'qs .*-c ii' 2>/dev/null || true
    sleep 0.5
fi

echo "→ Nothing shell: $ROOT/quickshell/nothing"
exec qs -p "$ROOT/quickshell/nothing"

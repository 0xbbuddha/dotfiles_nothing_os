#!/usr/bin/env bash
set -u

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/fallback-lock/common.sh"

exec 9>"$RUNTIME_DIR/nothing-lock-watch.lock"
flock -n 9 || exit 0

compositor_alive() {
    [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] \
        || [ -S "$RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ]
}

start_shell() {
    setsid -f qs -p "$1" >/dev/null 2>&1 9>&-
}

while compositor_alive; do
    if [ -e "$LOCK_FLAG" ] && ! pgrep -x qs >/dev/null 2>&1; then
        dir="$(shell_dir)"
        start_shell "$dir"
        if ! wait_secure "$dir" 8; then
            flock -n "$FALLBACK_GUARD" qs -p "$FALLBACK_DIR" >/dev/null 2>&1 9>&-
            pgrep -x qs >/dev/null 2>&1 || start_shell "$dir"
        fi
    fi
    sleep 2
done

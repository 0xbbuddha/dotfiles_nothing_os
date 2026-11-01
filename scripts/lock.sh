#!/usr/bin/env bash
# Locks the session by asking the running shell to do it, and checks that
# the compositor really locked.
#
# This is what hypridle's lock_cmd and SUPER+L both call. The shell draws
# the lock itself on ext-session-lock, and the compositor keeps those
# surfaces up even if the shell dies. When the shell does not answer,
# scripts/fallback-lock locks on its own.
#
# The three buttons on the lock screen do not act. They arm an intent that
# expires, and that still asks for confirmation once PAM has accepted the
# password.
set -u

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/fallback-lock/common.sh"

lock_with_shell() {
    local dir="$1" attempt answer
    for attempt in 1 2; do
        answer="$(timeout 1.5 qs -p "$dir" ipc call lock activate 2>/dev/null)"
        case "$answer" in
            ok) return 0 ;;
            pending) wait_secure "$dir" 7; return ;;
        esac
        [ "$attempt" = 1 ] && sleep 0.2
    done
    return 1
}

if fallback_running && wait_secure "$FALLBACK_DIR" 1; then
    exit 0
fi

SHELLDIR="$(shell_dir)"
lock_with_shell "$SHELLDIR" && exit 0

if ! fallback_running; then
    setsid -f flock -n "$FALLBACK_GUARD" qs -p "$FALLBACK_DIR" >/dev/null 2>&1
fi
wait_secure "$FALLBACK_DIR" 7 && exit 0
is_secure "$SHELLDIR" && exit 0

# Deliberately loud, and through the compositor: the notification server
# lives in the shell, which is the part that just failed.
echo "nothing: neither the shell nor the fallback locked, the session is NOT locked" >&2
hyprctl notify 0 15000 "rgb(ff4444)" "Lock failed: the session is NOT locked" >/dev/null 2>&1
exit 1

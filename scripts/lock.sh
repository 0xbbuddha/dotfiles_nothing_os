#!/usr/bin/env bash
# Locks the session, then carries out whatever the lock screen armed.
#
# The three buttons on the lock screen do not act. They write an intent,
# and it is honoured here only after hyprlock has exited successfully,
# which it only does once the password has been accepted. Anyone else can
# press them as much as they like: kill hyprlock and it exits non-zero,
# so the intent is dropped rather than obeyed.
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/nothing-lock-action"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF="${NOTHING_LOCK_CONF:-$HERE/../hypr/hyprlock.conf}"

# Already locked: do not stack a second instance over the first.
pidof hyprlock >/dev/null 2>&1 && exit 0

# The shell's own lock screen, when that is the one configured. Asking
# the running shell is also the test: if it does not answer "ok" we fall
# through to hyprlock rather than leaving the session open.
SHELLDIR="$HERE/../quickshell/nothing"
if [ "$(qs -p "$SHELLDIR" ipc call lock activate 2>/dev/null)" = "ok" ]; then
    exit 0
fi

# Never inherit an intent from a previous lock.
rm -f "$STATE"

started=$SECONDS
if ! hyprlock -c "$CONF" "$@"; then
    # Bailing out in under two seconds means it never drew: a broken
    # config would otherwise leave the screen simply not locking, which
    # is worse than losing the theme.
    if [ $((SECONDS - started)) -lt 2 ]; then
        hyprlock || true
    fi
    rm -f "$STATE"
    exit 0
fi

action="$(cat "$STATE" 2>/dev/null || true)"
rm -f "$STATE"

case "$action" in
    logout)
        # Exactly what Power.logout() runs in the shell, and for the same
        # reason: this config drives Hyprland's Lua parser, where the
        # classic `hyprctl dispatch exit` does not parse and fails in
        # silence. The pkill covers a client that refuses to close and
        # leaves the compositor stuck on a dead session.
        hyprctl dispatch 'hl.dsp.exit()'
        sleep 3
        pgrep -x Hyprland >/dev/null && pkill -x Hyprland
        ;;
    reboot)
        systemctl reboot || loginctl reboot
        ;;
    shutdown)
        systemctl poweroff || loginctl poweroff
        ;;
esac

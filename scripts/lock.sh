#!/usr/bin/env bash
# Locks the session by asking the running shell to do it.
#
# This is what hypridle's lock_cmd and SUPER+L both call. There is no
# second locker any more: the shell draws the lock itself on
# ext-session-lock, and the compositor keeps those surfaces up even if
# the shell dies, which is what makes a single locker safe.
#
# The three buttons on the lock screen do not act. They arm an intent
# that the shell carries out itself, and only once PAM has accepted the
# password, so anyone else can press them as much as they like.
set -u

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SHELLDIR="${NOTHING_SHELL_DIR:-$HERE/../quickshell/nothing}"

if [ "$(qs -p "$SHELLDIR" ipc call lock activate 2>/dev/null)" = "ok" ]; then
    exit 0
fi

# Deliberately loud. A shell that does not answer cannot lock, and the
# screen is still open: saying nothing here is how a machine ends up
# sitting unlocked because a lock command quietly failed.
echo "nothing: the shell did not answer, the session is NOT locked" >&2
notify-send -u critical "Lock failed" \
    "The Nothing shell did not answer. The session is not locked." 2>/dev/null
exit 1

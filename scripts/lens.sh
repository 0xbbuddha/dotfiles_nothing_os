#!/usr/bin/env bash
# Google Lens image search on a screen selection.
#
# WARNING: the captured region is SENT to a third-party host
# (uguu.se) to get a public URL, then opened in Google Lens.
# Do not select anything confidential.
set -uo pipefail

ENDPOINT="https://uguu.se/upload"
LENS="https://lens.google.com/uploadbyurl?url="
DIR="$(mktemp -d /tmp/nothing-lens-XXXXXX)"
NAME="shot.png"
TMP="$DIR/$NAME"

trap 'rm -rf "$DIR"' EXIT

# slurp plus grim, deliberately, and not hyprshot.
#
# hyprshot's last line is `begin_grab $OPTION & checkRunning`: the grab,
# and so the grim that writes the file, runs in the background while the
# foreground returns as soon as slurp disappears. That is the moment you
# release the mouse, not the moment the file exists, so the check below
# ran against a file that was not written yet and every capture came back
# "Cancelled". This path is synchronous.
#
# No screen freeze either. hyprpicker was tried for that and is the wrong
# tool: -z is --no-zoom, not --freeze, and hyprpicker is a colour picker
# that takes the pointer and the keyboard for a fullscreen surface. Run
# alongside slurp it leaves two grabbers fighting over the same input and
# the desktop looks like it has locked up.
GEO="$(slurp -d -b 00000080 -c d71921ff -w 2)" || { echo "Cancelled"; exit 1; }
grim -g "$GEO" "$TMP" || { echo "Capture failed"; exit 1; }

[[ -s "$TMP" ]] || { echo "Cancelled"; exit 1; }

URL="$(curl -sF "files[]=@$TMP" "$ENDPOINT" | jq -r '.files[0].url' 2>/dev/null)"
if [[ -z "$URL" || "$URL" == "null" ]]; then
    echo "Upload failed"; exit 1
fi

# xdg-open consults $BROWSER before the desktop association, and takes
# it on faith. Here /etc/environment carries BROWSER=helium while the
# binary is helium-browser, so xdg-open failed without a word and nothing
# opened. Only keep the variable if it actually runs; cleared, xdg-open
# falls back to the .desktop association, which is right.
if [[ -n "${BROWSER:-}" ]] && ! command -v "${BROWSER%% *}" >/dev/null 2>&1; then
    unset BROWSER
fi

# xdg-open returns immediately; detach cleanly
setsid xdg-open "${LENS}${URL}" >/dev/null 2>&1 < /dev/null &
disown 2>/dev/null || true
echo "Opened in Google Lens"

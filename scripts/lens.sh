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

# Use a file instead of -r: hyprshot's getopt declares this option as
# taking an argument and rejects it as-is.
if command -v hyprshot >/dev/null 2>&1; then
    hyprshot -m region -z -s -o "$DIR" -f "$NAME" >/dev/null 2>&1
else
    GEO="$(slurp -d -b 00000080 -c d71921ff -w 2)" || { echo "Cancelled"; exit 1; }
    grim -g "$GEO" "$TMP" || { echo "Capture failed"; exit 1; }
fi

[[ -s "$TMP" ]] || { echo "Cancelled"; exit 1; }

URL="$(curl -sF "files[]=@$TMP" "$ENDPOINT" | jq -r '.files[0].url' 2>/dev/null)"
if [[ -z "$URL" || "$URL" == "null" ]]; then
    echo "Upload failed"; exit 1
fi

# xdg-open returns immediately; detach cleanly
setsid xdg-open "${LENS}${URL}" >/dev/null 2>&1 < /dev/null &
disown 2>/dev/null || true
echo "Opened in Google Lens"

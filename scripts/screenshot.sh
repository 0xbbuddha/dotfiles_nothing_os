#!/usr/bin/env bash
# Screenshot helper for the Nothing shell.
#   screenshot.sh <region|window|screen|geo|freeze> <copy|save|edit|ocr> [geo] [output]
#
# freeze: crop the pre-overlay grim in /tmp/nothing-snip/<output>.png
# so the picker veil is not baked into the shot.
# Writes a short message to stdout, shown as a notification by the shell.
#
# Prefer hyprshot when available: it freezes the screen during selection
# (-z) and can target a whole window, which slurp alone cannot do.
set -uo pipefail

MODE="${1:-region}"
ACTION="${2:-copy}"
GEO="${3:-}"
OUTPUT="${4:-}"
DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Captures"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"
SNIP_DIR="/tmp/nothing-snip"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$DIR"

have() { command -v "$1" >/dev/null 2>&1; }

capture() {
    if [[ "$MODE" == "freeze" ]]; then
        local src="$SNIP_DIR/${OUTPUT}.png"
        [[ -n "$GEO" && -n "$OUTPUT" && -s "$src" ]] || return 1
        python3 "$ROOT/scripts/crop-snip.py" "$src" "$FILE" "$GEO"
        return
    fi

    if [[ "$MODE" == "geo" ]]; then
        [[ -n "$GEO" ]] || return 1
        grim -g "$GEO" "$FILE"
        return
    fi

    if have hyprshot; then
        local hm
        case "$MODE" in
            region) hm="region" ;;
            window) hm="window" ;;
            screen) hm="output" ;;
        esac
        # --freeze keeps the image still while we select
        local args=(-m "$hm" -z -s -o "$DIR" -f "$(basename "$FILE")")
        [[ "$MODE" == "screen" ]] && args=(-m output -m "$(hyprctl -j activeworkspace | jq -r .monitor)" -s -o "$DIR" -f "$(basename "$FILE")")
        hyprshot "${args[@]}" >/dev/null 2>&1
        [[ -s "$FILE" ]]
        return
    fi

    # Fallback without hyprshot: slurp plus grim, no screen freeze.
    local geo=""
    case "$MODE" in
        region) geo="$(slurp -d -b 00000080 -c d71921ff -w 2)" || return 1 ;;
        window) geo="$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" ;;
    esac
    if [[ -n "$geo" ]]; then grim -g "$geo" "$FILE"; else grim "$FILE"; fi
}

capture || { echo "Cancelled"; exit 1; }

case "$ACTION" in
    copy)
        wl-copy < "$FILE"
        echo "Copied and saved"
        ;;
    save)
        echo "Saved"
        ;;
    edit)
        if have swappy; then
            swappy -f "$FILE" >/dev/null 2>&1 &
            echo "Opened in swappy"
        else
            wl-copy < "$FILE"
            echo "swappy missing, copied instead"
        fi
        ;;
    ocr)
        if ! have tesseract; then echo "tesseract is not installed"; exit 1; fi
        LANGS="eng"
        tesseract --list-langs 2>/dev/null | grep -qx fra && LANGS="fra+eng"
        TEXT="$(tesseract "$FILE" - -l "$LANGS" 2>/dev/null)"
        rm -f "$FILE"
        if [[ -z "${TEXT// }" ]]; then echo "No text detected"; exit 1; fi
        printf '%s' "$TEXT" | wl-copy
        echo "Text copied ($(printf '%s' "$TEXT" | wc -c) characters)"
        ;;
esac

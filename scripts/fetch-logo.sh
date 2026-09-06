#!/usr/bin/env bash
# Pick the fastfetch logo.
#
#   scripts/fetch-logo.sh              what is set now
#   scripts/fetch-logo.sh arch         the Arch mountain, in dots
#   scripts/fetch-logo.sh nothing      the Nothing mark, in dots
#   scripts/fetch-logo.sh tamaki       your own PNG, through kitty
#
# fastfetch loads exactly one config file, and a PNG needs a different
# logo type from a text grid, so the choice cannot be a second config: it
# is two lines rewritten in the one you have. They carry // logo-type and
# // logo-source markers so this stays a two-line edit rather than a JSON
# parser for a file full of comments.
#
# Shipping this as a script rather than a shell function is deliberate:
# it then works from fish, bash, zsh or a launcher, and it does not
# shadow the fastfetch binary.
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
FILE="$CONF/config.jsonc"
PNG="$CONF/pngs/tamaki.png"

[[ -f "$FILE" ]] || { echo "no $FILE (run ./install --files)" >&2; exit 1; }

current() {
    local src
    src=$(grep -- "// logo-source" "$FILE" | sed 's/.*"source": *"\([^"]*\)".*/\1/')
    case "$src" in
        *nothing.txt) echo nothing ;;
        *arch.txt)    echo arch ;;
        *.png)        echo tamaki ;;
        *)            echo "$src" ;;
    esac
}

if [[ $# -eq 0 ]]; then
    current
    exit 0
fi

case "$1" in
    arch)    type=file;         source="~/.config/fastfetch/logos/arch.txt" ;;
    nothing) type=file;         source="~/.config/fastfetch/logos/nothing.txt" ;;
    tamaki)
        [[ -s "$PNG" ]] || {
            echo "no $PNG. Drop your PNG there first." >&2; exit 1; }
        type=kitty-direct; source="~/.config/fastfetch/pngs/tamaki.png" ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "fetch-logo: arch, nothing or tamaki" >&2; exit 1 ;;
esac

# The width the dot grids need is their own; a PNG is told how tall to be.
tmp=$(mktemp)
sed -e "s|\(\"type\": *\)\"[^\"]*\"\(.*// logo-type\)|\1\"$type\"\2|" \
    -e "s|\(\"source\": *\)\"[^\"]*\"\(.*// logo-source\)|\1\"$source\"\2|" \
    "$FILE" > "$tmp"
mv "$tmp" "$FILE"

# kitty-direct wants a height; the text grids bring their own and would
# be stretched by one.
if [[ "$type" == kitty-direct ]]; then
    grep -q '"height"' "$FILE" || sed -i \
        's|\(.*// logo-source\)|\1\n    "height": 18,|' "$FILE"
else
    sed -i '/^ *"height": 18,$/d' "$FILE"
fi

echo "logo: $(current)"

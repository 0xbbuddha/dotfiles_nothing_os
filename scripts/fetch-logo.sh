#!/usr/bin/env bash
# Pick the fastfetch logo, or have it take turns.
#
#   scripts/fetch-logo.sh                          what is set now
#   scripts/fetch-logo.sh arch                     the Arch mountain, in dots
#   scripts/fetch-logo.sh nothing                  the Nothing mark, in dots
#   scripts/fetch-logo.sh tamaki                   your own PNG, through kitty
#   scripts/fetch-logo.sh alternate arch tamaki    a different one each run
#
# fastfetch loads exactly one config file and draws the logo named in it,
# so pinning is a rewrite of that file's "logo" block, and alternating
# cannot live there at all: it is a list in ~/.config/fastfetch/logo that
# the fish function reads per run and passes as flags.
#
# A script rather than a shell function, so pinning works from fish,
# bash, zsh or a launcher, and does not shadow the fastfetch binary.
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
FILE="$CONF/config.jsonc"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nothing/fetch-logo"

[[ -f "$FILE" ]] || { echo "no $FILE (run ./install --files)" >&2; exit 1; }

valid() {
    case "$1" in
        arch|nothing|tamaki) return 0 ;;
        *) echo "fetch-logo: arch, nothing or tamaki, not '$1'" >&2; return 1 ;;
    esac
}

# Rewrites the config's "logo" block. Whole block rather than a line or
# two: the types need different keys, and a picture needs a width and a
# height that a text grid must not have.
pin() {
    python3 - "$FILE" "$CONF" "$1" <<'PY'
import io, os, sys
path, conf, want = sys.argv[1], sys.argv[2], sys.argv[3]
src = io.open(path, encoding="utf-8").read()
start = src.index('  "logo": {')
end = src.index("\n  },", start) + len("\n  },")

if want == "tamaki":
    png = os.path.join(conf, "pngs/tamaki.png")
    if not os.path.isfile(png) or os.path.getsize(png) == 0:
        sys.stderr.write("no %s. Drop your PNG there first.\n" % png)
        raise SystemExit(1)
    new = '''  "logo": {
    "type": "kitty-direct",
    "source": "~/.config/fastfetch/pngs/tamaki.png",
    // A picture has to be told how many cells to occupy in both
    // directions. Give it only a height and fastfetch reserves too few
    // columns, and the image is drawn straight over the first column of
    // text. A terminal cell is about twice as tall as it is wide, so a
    // square image wants a box twice as wide as it is high; 36 rather
    // than 34 leaves slack for a font whose cells are narrower.
    "width": 36,
    "height": 17,
    "padding": { "left": 2, "right": 4, "top": 1 }
  },'''
else:
    new = '''  "logo": {
    "type": "file",
    "source": "~/.config/fastfetch/logos/%s.txt",
    // $1 is a lit dot, $2 an unlit one. The grid carries its own size,
    // so no width or height here: giving one would stretch it.
    "color": { "1": "#ffffff", "2": "#262626" },
    "padding": { "left": 2, "right": 4, "top": 1 }
  },''' % want

io.open(path, "w", encoding="utf-8").write(src[:start] + new + src[end:])
PY
}

case "${1:-}" in
    -h|--help)
        sed -n '2,9p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    "")
        # More than one name in the file means it is taking turns.
        names=()
        [[ -f "$CONF/logo" ]] && read -r -a names < "$CONF/logo" || true
        if [[ ${#names[@]} -gt 1 ]]; then
            echo "alternating: ${names[*]}"
        elif [[ ${#names[@]} -eq 1 ]]; then
            echo "${names[0]}"
        else
            echo arch
        fi
        exit 0
        ;;
    alternate)
        shift
        names=("$@")
        [[ ${#names[@]} -eq 0 ]] && names=(arch tamaki)
        if [[ ${#names[@]} -lt 2 ]]; then
            echo "fetch-logo: alternate needs at least two names" >&2
            exit 1
        fi
        for n in "${names[@]}"; do valid "$n"; done
        # Point the config at the first, so a plain fastfetch outside
        # fish shows that one rather than whatever was there before.
        pin "${names[0]}"
        printf '%s\n' "${names[*]}" > "$CONF/logo"
        rm -f "$STATE"
        echo "alternating: ${names[*]}"
        ;;
    *)
        valid "$1"
        pin "$1"
        # Naming one cancels any alternation.
        printf '%s\n' "$1" > "$CONF/logo"
        echo "logo: $1"
        ;;
esac

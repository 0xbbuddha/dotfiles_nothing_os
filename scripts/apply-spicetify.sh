#!/usr/bin/env bash
# Apply the Nothing theme to Spotify, through spicetify.
#
#   ./scripts/apply-spicetify.sh              install and apply
#   ./scripts/apply-spicetify.sh --light      the light scheme
#   ./scripts/apply-spicetify.sh --fix-perms  chown /opt/spotify first (sudo)
#   ./scripts/apply-spicetify.sh --revert     put Spotify back
#
# The one thing this cannot do for you: spicetify patches Spotify in place,
# so /opt/spotify has to be writable by your user. That needs root, and
# handing root to a theme installer without saying so is not on. Run
# --fix-perms, or the two commands it prints, yourself.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
NAME="nothing"
SCHEME="dark"
FIX_PERMS=0
REVERT=0

for arg in "$@"; do
    case "$arg" in
        --light)     SCHEME="light" ;;
        --dark)      SCHEME="dark" ;;
        --fix-perms) FIX_PERMS=1 ;;
        --revert)    REVERT=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if ! command -v spicetify >/dev/null 2>&1; then
    cat >&2 <<'MSG'
spicetify is not installed.

    yay -S spicetify-cli        # or: paru -S spicetify-cli

Then run this script again.
MSG
    exit 1
fi

if [[ $REVERT -eq 1 ]]; then
    echo "→ Restoring Spotify"
    spicetify restore || true
    echo "Done. Reopen Spotify."
    exit 0
fi

# ── The permission problem ───────────────────────────────────────────────
# The pacman package installs Spotify root-owned under /opt. spicetify
# rewrites the app bundle, so it needs write access to that directory.
SPOTIFY_DIR=""
for d in /opt/spotify /usr/share/spotify /opt/spotify-launcher; do
    [[ -d "$d" ]] && { SPOTIFY_DIR="$d"; break; }
done

if [[ -z "$SPOTIFY_DIR" ]]; then
    echo "Spotify's install directory was not found. Is it installed?" >&2
    echo "A flatpak install works too, but spicetify has to be pointed at" >&2
    echo "it by hand: see spicetify's docs for spotify_path." >&2
    exit 1
fi

if [[ ! -w "$SPOTIFY_DIR/Apps" && ! -w "$SPOTIFY_DIR" ]]; then
    if [[ $FIX_PERMS -eq 1 ]]; then
        echo "→ Making $SPOTIFY_DIR writable (sudo)"
        sudo chmod a+wr "$SPOTIFY_DIR"
        sudo chmod a+wr -R "$SPOTIFY_DIR/Apps"
    else
        cat >&2 <<MSG
$SPOTIFY_DIR is not writable, and spicetify patches Spotify in place.

Run this script with --fix-perms, or run these two yourself:

    sudo chmod a+wr $SPOTIFY_DIR
    sudo chmod a+wr -R $SPOTIFY_DIR/Apps

A Spotify update resets both, and the theme goes with them. Re-run this
script after any spotify upgrade.
MSG
        exit 1
    fi
fi

# ── Install the theme ────────────────────────────────────────────────────
# spicetify -c prints the path of its own config file; the Themes directory
# sits beside it. Asking is better than guessing: the path moved between
# spicetify 1 and 2.
SPICE_CONF="$(spicetify -c)"
SPICE_DIR="$(dirname "$SPICE_CONF")"
DEST="$SPICE_DIR/Themes/$NAME"

mkdir -p "$DEST"
install -m644 "$ROOT/theme/spicetify/$NAME/color.ini" "$DEST/color.ini"
install -m644 "$ROOT/theme/spicetify/$NAME/user.css"  "$DEST/user.css"
echo "→ $DEST/"

# The shell lets you pick an accent, and a Spotify that keeps the stock red
# while the bar is orange is the one window on screen that is off. Read it
# back out of the live config and patch the two keys that carry it.
ACCENT="$(python3 - "$CONF/nothing/config.json" <<'PY'
import json, re, sys
try:
    with open(sys.argv[1]) as f:
        a = json.load(f).get("accent", "")
except Exception:
    a = ""
print(a.lstrip("#").upper() if re.fullmatch(r"#?[0-9a-fA-F]{6}", a or "") else "")
PY
)"

if [[ -n "$ACCENT" ]]; then
    # button only: notification-error stays red whatever the accent is,
    # because an error that matches the play button is not an error.
    sed -i -E "s/^(button|button-active)( *)=.*/\1\2= $ACCENT/" "$DEST/color.ini"
    echo "→ accent #$ACCENT, from the shell's config"
fi

# ── Apply ────────────────────────────────────────────────────────────────
spicetify config current_theme "$NAME"
spicetify config color_scheme "$SCHEME"
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1

# backup apply on a machine that has never been patched, plain apply after
# that: a second backup would snapshot the already-themed client, and
# spicetify refuses it and does nothing at all rather than falling back.
#
# The marker is the version line spicetify writes under [Backup] in its own
# config, not a Backup directory: 2.x keeps the copy outside the config
# directory, so looking for the folder there says "never patched" on a
# machine that has been patched for months.
if grep -qE '^version[[:space:]]*=[[:space:]]*[^[:space:]]' \
        <(sed -n '/^\[Backup\]/,$p' "$SPICE_CONF"); then
    spicetify apply
else
    spicetify backup apply
fi

cat <<MSG

Done. Reopen Spotify.

  scheme      $SCHEME     (--light / --dark to switch)
  undo        ./scripts/apply-spicetify.sh --revert

After a spotify package upgrade the patch is gone: re-run this script.
MSG

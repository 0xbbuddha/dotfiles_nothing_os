#!/usr/bin/env bash
# Apply the Nothing theme to Spotify, through spicetify.
#
#   ./scripts/apply-spicetify.sh              install and apply
#   ./scripts/apply-spicetify.sh --light      force the light scheme
#   ./scripts/apply-spicetify.sh --fix-perms  make /opt/spotify writable first
#   ./scripts/apply-spicetify.sh --revert     put Spotify back
#   ./scripts/apply-spicetify.sh --status     print the state, change nothing
#
# Both the accent and the light/dark scheme are read out of the shell's own
# config.json, so Spotify follows whatever the rest of the desktop is set
# to. The flags are there to override that from a terminal.
#
# The one thing this needs root for: spicetify patches Spotify in place, so
# /opt/spotify has to be writable by your user. --fix-perms asks for that,
# through sudo on a terminal and through pkexec when there is no terminal
# to type into, which is how the settings panel calls it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_CONF="$CONF/nothing/config.json"
NAME="nothing"
MARKER="Nothing, for Spotify"
SCHEME=""
FIX_PERMS=0
REVERT=0
STATUS=0

for arg in "$@"; do
    case "$arg" in
        --light)     SCHEME="light" ;;
        --dark)      SCHEME="dark" ;;
        --fix-perms) FIX_PERMS=1 ;;
        --revert)    REVERT=1 ;;
        --status)    STATUS=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# ── What the shell is set to ─────────────────────────────────────────────
# One python call for both values: config.json is JSON, and a grep for a
# key in JSON is a bug waiting for the day someone reformats the file.
read -r WANT_ACCENT WANT_SCHEME <<<"$(python3 - "$SHELL_CONF" <<'PY'
import json, re, sys
accent, theme = "", "dark"
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    a = d.get("accent", "") or ""
    if re.fullmatch(r"#?[0-9a-fA-F]{6}", a):
        accent = a.lstrip("#").upper()
    if d.get("theme") == "light":
        theme = "light"
except Exception:
    pass
print(accent or "-", theme)
PY
)"
[[ "$WANT_ACCENT" == "-" ]] && WANT_ACCENT=""
[[ -z "$SCHEME" ]] && SCHEME="$WANT_SCHEME"

# ── Where Spotify is ─────────────────────────────────────────────────────
SPOTIFY_DIR=""
for d in /opt/spotify /usr/share/spotify /opt/spotify-launcher; do
    [[ -d "$d" ]] && { SPOTIFY_DIR="$d"; break; }
done

have_spicetify() { command -v spicetify >/dev/null 2>&1; }

writable() {
    [[ -n "$SPOTIFY_DIR" ]] && [[ -w "$SPOTIFY_DIR/Apps" || -w "$SPOTIFY_DIR" ]]
}

# ── Status ───────────────────────────────────────────────────────────────
# key=value lines, one per line, meant to be parsed. Everything else this
# script prints goes to a human; this is the only machine-readable output,
# and it is why the settings panel can show a state at all.
if [[ $STATUS -eq 1 ]]; then
    applied=0; accent=""; scheme=""
    if have_spicetify; then
        conf="$(spicetify -c 2>/dev/null || true)"
        css="$SPOTIFY_DIR/Apps/xpui/user.css"
        if [[ -n "$SPOTIFY_DIR" && -f "$css" ]] && grep -q "$MARKER" "$css"; then
            applied=1
            # What the patched client actually carries, not what we would
            # write now: the difference between the two is exactly what
            # tells the panel the theme is out of date.
            accent="$(sed -n 's/^ *--spice-button: *#\?\([0-9a-fA-F]\{6\}\).*/\1/p' \
                "$SPOTIFY_DIR/Apps/xpui/colors.css" 2>/dev/null | head -1 \
                | tr '[:lower:]' '[:upper:]')"
            [[ -n "$conf" ]] && scheme="$(sed -n \
                's/^color_scheme *= *\([a-z]*\).*/\1/p' "$conf" | head -1)"
        fi
    fi
    printf 'spotify=%d\n'   "$([[ -n $SPOTIFY_DIR ]] && echo 1 || echo 0)"
    printf 'spicetify=%d\n' "$(have_spicetify && echo 1 || echo 0)"
    printf 'writable=%d\n'  "$(writable && echo 1 || echo 0)"
    printf 'applied=%d\n'   "$applied"
    printf 'accent=%s\n'    "$accent"
    printf 'scheme=%s\n'    "$scheme"
    printf 'wantAccent=%s\n' "$WANT_ACCENT"
    printf 'wantScheme=%s\n' "$SCHEME"
    printf 'dir=%s\n'        "$SPOTIFY_DIR"
    exit 0
fi

if ! have_spicetify; then
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

if [[ -z "$SPOTIFY_DIR" ]]; then
    echo "Spotify's install directory was not found. Is it installed?" >&2
    echo "A flatpak install works too, but spicetify has to be pointed at" >&2
    echo "it by hand: see spicetify's docs for spotify_path." >&2
    exit 1
fi

# ── The permission problem ───────────────────────────────────────────────
# The package installs Spotify root-owned under /opt, and spicetify
# rewrites the app bundle in place.
if ! writable; then
    if [[ $FIX_PERMS -eq 1 ]]; then
        # One escalation, not two: two chmod calls behind two prompts is
        # two passwords for one action. sudo when there is a terminal to
        # type the password into, pkexec when there is not, which is the
        # case whenever the settings panel is the caller. The shell runs
        # its own polkit agent, so pkexec gets a dialog in the same
        # language as the rest of the desktop.
        fix="chmod a+wr '$SPOTIFY_DIR' && chmod -R a+wr '$SPOTIFY_DIR/Apps'"
        echo "→ Making $SPOTIFY_DIR writable"
        if [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
            sudo sh -c "$fix"
        elif command -v pkexec >/dev/null 2>&1; then
            pkexec sh -c "$fix"
        else
            echo "neither sudo on a terminal nor pkexec is available" >&2
            exit 1
        fi
    else
        cat >&2 <<MSG
$SPOTIFY_DIR is not writable, and spicetify patches Spotify in place.

Run this script with --fix-perms, or run these two yourself:

    sudo chmod a+wr $SPOTIFY_DIR
    sudo chmod -R a+wr $SPOTIFY_DIR/Apps

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

# A Spotify that keeps the stock red while the bar is orange is the one
# window on screen that is off.
if [[ -n "$WANT_ACCENT" ]]; then
    # button only: notification-error stays red whatever the accent is,
    # because an error that matches the play button is not an error.
    sed -i -E "s/^(button|button-active)( *)=.*/\1\2= $WANT_ACCENT/" "$DEST/color.ini"
    echo "→ accent #$WANT_ACCENT and the $SCHEME scheme, from the shell's config"
fi

# ── Apply ────────────────────────────────────────────────────────────────
spicetify config current_theme "$NAME" >/dev/null
spicetify config color_scheme "$SCHEME" >/dev/null
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 >/dev/null
# spicetify asks GitHub whether it is out of date on every run, and prints a
# rate-limit error when GitHub says no. Applying a theme is not the moment to
# find out about a new release, and the shell shows that error to the user.
spicetify config check_spicetify_update 0 >/dev/null

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

  scheme      $SCHEME     (--light / --dark to force the other)
  undo        ./scripts/apply-spicetify.sh --revert

After a spotify package upgrade the patch is gone: re-run this script.
MSG

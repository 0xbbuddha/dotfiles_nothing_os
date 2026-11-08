#!/usr/bin/env bash
# Apply the Nothing theme to Spotify, through spicetify.
#
#   ./scripts/apply-spicetify.sh              install and apply
#   ./scripts/apply-spicetify.sh --light      force the light scheme
#   ./scripts/apply-spicetify.sh --fix-perms  give your user write access to /opt/spotify first
#   ./scripts/apply-spicetify.sh --revert     put Spotify back
#   ./scripts/apply-spicetify.sh --status     print the state, change nothing
#
# Both the accent and the light/dark scheme are read out of the shell's own
# config.json, so Spotify follows whatever the rest of the desktop is set
# to. The flags are there to override that from a terminal.
#
# The one thing this needs root for: spicetify patches Spotify in place, so
# /opt/spotify has to be writable by your user. --fix-perms asks for that
# with an ACL for your user alone, through sudo on a terminal and through pkexec when there is no terminal
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
# Accent: shared with apply-zen-theme.sh via read-accent.py, which only
# reads and validates - spicetify's color.ini wants bare uppercase hex,
# so that part stays here.
WANT_ACCENT="$(python3 "$ROOT/scripts/read-accent.py" "$SHELL_CONF" | tr '[:lower:]' '[:upper:]')"
WANT_SCHEME="$(python3 - "$SHELL_CONF" <<'PY'
import json, sys
theme = "dark"
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    if d.get("theme") == "light":
        theme = "light"
except Exception:
    pass
print(theme)
PY
)"
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
    cat <<'MSG'
spicetify is not installed.

    yay -S spicetify-cli        # or: paru -S spicetify-cli

Then run this script again.
MSG
    exit 1
fi

if [[ $REVERT -eq 1 ]]; then
    echo "→ Restoring Spotify"
    spicetify restore || true

    # spicetify restore reports success (and this script used to take its
    # word for it with `|| true`) even when it had no backup to restore
    # from - which happens the moment a Spotify package update replaces
    # /opt/spotify wholesale and spicetify's own backup copy with it. The
    # client was left fully themed while this script said "Done."
    # Checking the one file the theme actually marks is the only way to
    # know restore did anything at all.
    #
    # The fix for that case is a full package reinstall, which needs a
    # password - and a password belongs in a terminal the user is
    # looking at, not a process started behind this panel's spinner
    # with no terminal to answer sudo's prompt in: that combination is
    # exactly what first looked like "Removing hangs forever" here, not
    # a clean failure. So this names the problem and the exact command,
    # and stops - the same reason Spicetify.qml's installSpicetify()
    # opens an actual terminal for `yay -S spicetify-cli` rather than
    # running it itself.
    css="$SPOTIFY_DIR/Apps/xpui/user.css"
    if [[ -n "$SPOTIFY_DIR" ]] && [[ -f "$css" ]] && grep -q "$MARKER" "$css"; then
        echo "spicetify's own backup is gone, so restore could not undo"
        echo "the theme. Run this yourself in a terminal, then reopen"
        echo "Spotify:"
        echo
        echo "    sudo pacman -S spotify"
        exit 1
    fi

    echo "Done. Reopen Spotify."
    exit 0
fi

if [[ -z "$SPOTIFY_DIR" ]]; then
    echo "Spotify's install directory was not found. Is it installed?"
    echo "A flatpak install works too, but spicetify has to be pointed at"
    echo "it by hand: see spicetify's docs for spotify_path."
    exit 1
fi

# ── The permission problem ───────────────────────────────────────────────
# The package installs Spotify root-owned under /opt, and spicetify
# rewrites the app bundle in place.
if ! writable; then
    if [[ $FIX_PERMS -eq 1 ]]; then
        # One escalation, not two: two setfacl calls behind two prompts is
        # two passwords for one action. sudo when there is a terminal to
        # type the password into, pkexec when there is not, which is the
        # case whenever the settings panel is the caller. The shell runs
        # its own polkit agent, so pkexec gets a dialog in the same
        # language as the rest of the desktop.
        if ! command -v setfacl >/dev/null 2>&1; then
            echo "setfacl is missing: install the acl package, or make"
            echo "$SPOTIFY_DIR writable for your user yourself."
            echo "It is never opened to everyone."
            exit 1
        fi
        me="$(id -un)"
        fix='setfacl -m "u:$1:rwx" "$2" && setfacl -R -m "u:$1:rwX" "$2/Apps"'
        echo "→ Giving $me write access to $SPOTIFY_DIR (ACL for $me only)"
        if [[ -t 0 ]] && command -v sudo >/dev/null 2>&1; then
            sudo sh -c "$fix" "nothing-spicetify-grant-$me" "$me" "$SPOTIFY_DIR"
        elif command -v pkexec >/dev/null 2>&1; then
            pkexec sh -c "$fix" "nothing-spicetify-grant-$me" "$me" "$SPOTIFY_DIR"
        else
            echo "neither sudo on a terminal nor pkexec is available"
            exit 1
        fi
    else
        cat <<MSG
$SPOTIFY_DIR is not writable, and spicetify patches Spotify in place.

Run this script with --fix-perms, or run these two yourself:

    sudo setfacl -m u:$USER:rwx $SPOTIFY_DIR
    sudo setfacl -R -m u:$USER:rwX $SPOTIFY_DIR/Apps

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

# backup apply on a machine that has never been patched, or whose backup
# no longer matches the Spotify that is actually installed; plain apply
# once the two agree. Checking only "does a version line exist" (what
# this used to do) missed the far more common case: Spotify updates on
# its own every few weeks, the recorded backup does not, and `spicetify
# apply` against a stale backup is exactly what printed "Spotify version
# and backup version are mismatched" and left the theme stuck - restore
# had nothing current to restore from, and apply had nothing current to
# apply onto. `spotify --version` prints the exact same string spicetify
# records under [Backup], so the comparison is exact, not a guess.
#
# The marker is the version line spicetify writes under [Backup] in its own
# config, not a Backup directory: 2.x keeps the copy outside the config
# directory, so looking for the folder there says "never patched" on a
# machine that has been patched for months.
backup_version="$(sed -n 's/^version[[:space:]]*=[[:space:]]*//p' \
    <(sed -n '/^\[Backup\]/,$p' "$SPICE_CONF") | head -1)"
live_version="$("$SPOTIFY_DIR/spotify" --version 2>/dev/null \
    | sed -n 's/^Spotify version \([^,]*\),.*/\1/p')"
if [[ -n "$backup_version" && -n "$live_version" && "$backup_version" == "$live_version" ]]; then
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

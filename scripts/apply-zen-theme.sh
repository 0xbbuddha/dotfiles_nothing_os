#!/usr/bin/env bash
# Apply the Nothing theme to Zen Browser, through userChrome.css /
# userContent.css.
#
#   ./scripts/apply-zen-theme.sh            install and apply
#   ./scripts/apply-zen-theme.sh --revert   remove it
#   ./scripts/apply-zen-theme.sh --status   print the state, change nothing
#
# The accent is read out of the shell's own config.json, same as
# apply-spicetify.sh, so Zen follows whatever the rest of the desktop is
# set to. Dark/light need no equivalent flag: both ship in the same CSS
# behind prefers-color-scheme, which already follows the system GTK
# theme that apply-app-theme.sh keeps in sync with Config.theme.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
SHELL_CONF="$CONF/nothing/config.json"
MARKER="Nothing OS theme for Zen Browser"

REVERT=0
STATUS=0
for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
        --status) STATUS=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# ── What the shell is set to ──────────────────────────────────────────
# Shared with apply-spicetify.sh via read-accent.py, which only reads
# and validates - Zen's CSS wants a lowercase '#rrggbb', so that part
# stays here.
HEX="$(python3 "$ROOT/scripts/read-accent.py" "$SHELL_CONF")"
if [[ -n "$HEX" ]]; then
    WANT_ACCENT="#$(tr '[:upper:]' '[:lower:]' <<<"$HEX")"
else
    WANT_ACCENT="#00d68f"
fi

# ── Where Zen keeps its profile ───────────────────────────────────────
# The profile a plain launch actually uses is whichever one the
# [InstallXXXX] section's Default= points at, not a bare Default=1 on
# a [ProfileN] section - Firefox-family browsers let a profile carry
# that flag without it being the one that launches.
ZEN_DIR=""
for d in "$CONF/zen" "$HOME/.zen"; do
    [[ -f "$d/profiles.ini" ]] && { ZEN_DIR="$d"; break; }
done

profile_dir() {
    [[ -n "$ZEN_DIR" ]] || return 1
    python3 - "$ZEN_DIR" <<'PY'
import configparser, sys
root = sys.argv[1]
c = configparser.ConfigParser()
c.read(f"{root}/profiles.ini")

rel = None
for s in c.sections():
    if s.startswith("Install"):
        rel = c[s].get("Default")
        break
if rel is None:
    for s in c.sections():
        if s.startswith("Profile") and c[s].get("Default") == "1":
            rel = c[s].get("Path")
            break
if rel is None:
    for s in c.sections():
        if s.startswith("Profile"):
            rel = c[s].get("Path")
            break
if rel:
    print(f"{root}/{rel}")
PY
}

have_zen() { [[ -n "$ZEN_DIR" ]] || command -v zen-browser >/dev/null 2>&1; }

# ── Status ─────────────────────────────────────────────────────────────
if [[ $STATUS -eq 1 ]]; then
    prof="$(profile_dir || true)"
    applied=0
    [[ -n "$prof" && -f "$prof/chrome/userChrome.css" ]] \
        && grep -q "$MARKER" "$prof/chrome/userChrome.css" && applied=1
    printf 'zen=%d\n'       "$(have_zen && echo 1 || echo 0)"
    printf 'profile=%s\n'   "${prof:-}"
    printf 'applied=%d\n'   "$applied"
    printf 'wantAccent=%s\n' "$WANT_ACCENT"
    exit 0
fi

if ! have_zen; then
    echo "Zen Browser was not found (no profiles.ini). Nothing to theme." >&2
    exit 0
fi

PROFILE="$(profile_dir || true)"
if [[ -z "$PROFILE" ]]; then
    echo "Could not work out Zen's default profile from $ZEN_DIR/profiles.ini" >&2
    exit 1
fi

if [[ $REVERT -eq 1 ]]; then
    rm -f "$PROFILE/chrome/userChrome.css" "$PROFILE/chrome/userContent.css"
    # Leave toolkit.legacyUserProfileCustomizations.stylesheets - a
    # generic, harmless Firefox pref - but drop the two Zen-native
    # overrides so the browser goes back to its own accent and corners.
    sed -i -e '/"zen\.theme\.accent-color"/d' -e '/"zen\.theme\.border-radius"/d' \
        "$PROFILE/user.js" 2>/dev/null || true
    echo "Removed. Restart Zen."
    exit 0
fi

mkdir -p "$PROFILE/chrome"
install -m644 "$ROOT/theme/zen/userChrome.css"  "$PROFILE/chrome/userChrome.css"
install -m644 "$ROOT/theme/zen/userContent.css" "$PROFILE/chrome/userContent.css"
sed -i "s/NOTHING_ACCENT/$WANT_ACCENT/g" \
    "$PROFILE/chrome/userChrome.css" "$PROFILE/chrome/userContent.css"
echo "-> $PROFILE/chrome/{userChrome,userContent}.css (accent $WANT_ACCENT)"

# user.js is read on every start and merged over prefs.js, so this
# survives even while Zen is running - unlike editing prefs.js
# directly, which Zen periodically rewrites from memory and would
# just overwrite back.
#
# zen.theme.accent-color and zen.theme.border-radius are Zen's own
# native theme prefs, not something this theme invented: its
# zenThemeModifier.js reads them straight from Services.prefs and
# writes --zen-primary-color/--zen-border-radius onto :root as a
# plain (non-!important) inline style every time either pref changes.
# Overriding those two variables from userChrome.css alone did not
# stick in practice, pref first.
USER_JS="$PROFILE/user.js"
set_user_pref() {
    local name="$1" line="user_pref(\"$1\", $2);"
    if grep -q "\"$name\"" "$USER_JS" 2>/dev/null; then
        sed -i "s|.*\"$name\".*|$line|" "$USER_JS"
    else
        printf '%s\n' "$line" >> "$USER_JS"
    fi
}
set_user_pref "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
set_user_pref "zen.theme.accent-color" "\"$WANT_ACCENT\""
set_user_pref "zen.theme.border-radius" "4"
echo "-> set prefs (custom stylesheets, accent, border radius) in $USER_JS"

echo
echo "Done. Restart Zen to see it."
echo
echo "  undo  ./scripts/apply-zen-theme.sh --revert"
echo
echo "A different accent in the shell's settings needs this re-run."

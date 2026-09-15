#!/usr/bin/env bash
# Installs the Nothing theme for Vesktop.
#
#   ./scripts/apply-vesktop-theme.sh           install and enable
#   ./scripts/apply-vesktop-theme.sh --revert  remove it
#   ./scripts/apply-vesktop-theme.sh --status  print the state, change nothing
#
# Vesktop only: it is what this rice's install offers Discord users, and
# its settings.json layout is not the same as stock Discord's or any other
# Vencord client's. Additive on the way in - enabledThemes is appended to,
# never replaced, so a tester's own themes survive this - and precise on
# the way out: --revert drops only "nothing.theme.css" from that list.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}/vesktop"
THEME_SRC="$ROOT/theme/vesktop/nothing.theme.css"
THEME_NAME="nothing.theme.css"
SETTINGS="$CONF/settings/settings.json"

REVERT=0
STATUS=0
for arg in "$@"; do
    case "$arg" in
        --revert) REVERT=1 ;;
        --status) STATUS=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

# A config directory means Vesktop has been run at least once; the binary
# alone does not, and there is nothing to write into yet on a machine
# where it has only just been pacman-installed.
have_vesktop() { [[ -d "$CONF" ]] || command -v vesktop >/dev/null 2>&1; }

# One python call for the read-modify-write: settings.json is JSON, and a
# sed edit on it is a bug waiting for the day a value contains a comma.
patch_settings() {
    local action="$1"
    python3 - "$SETTINGS" "$THEME_NAME" "$action" <<'PY'
import json, sys
path, name, action = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    d = json.load(f)
themes = [t for t in d.get("enabledThemes", []) if t != name]
if action == "enable":
    d["useQuickCss"] = True
    themes.append(name)
d["enabledThemes"] = themes
with open(path, "w") as f:
    json.dump(d, f, indent=4)
    f.write("\n")
PY
}

if [[ $STATUS -eq 1 ]]; then
    installed=0; enabled=0
    [[ -f "$CONF/themes/$THEME_NAME" ]] && installed=1
    if [[ -f "$SETTINGS" ]] \
        && python3 -c "import json,sys; sys.exit(0 if '$THEME_NAME' in json.load(open('$SETTINGS')).get('enabledThemes', []) else 1)" 2>/dev/null; then
        enabled=1
    fi
    printf 'vesktop=%d\n'   "$(have_vesktop && echo 1 || echo 0)"
    printf 'installed=%d\n' "$installed"
    printf 'enabled=%d\n'   "$enabled"
    exit 0
fi

if ! have_vesktop; then
    echo "Vesktop was not found (no ~/.config/vesktop). Nothing to theme." >&2
    exit 0
fi

if [[ $REVERT -eq 1 ]]; then
    rm -f "$CONF/themes/$THEME_NAME"
    [[ -f "$SETTINGS" ]] && patch_settings disable
    echo "Removed. Restart Vesktop."
    exit 0
fi

mkdir -p "$CONF/themes"
install -m644 "$THEME_SRC" "$CONF/themes/$THEME_NAME"
echo "-> $CONF/themes/$THEME_NAME"

if [[ ! -f "$SETTINGS" ]]; then
    cat <<MSG
Vesktop has never been run, so it has no settings.json yet. The theme is
in place; open Vesktop once, then enable it yourself: Settings > Vencord
> Themes > Nothing (turn on "Use QuickCSS and Themes" if it asks).
MSG
    exit 0
fi

patch_settings enable
echo "-> enabled in $SETTINGS"
echo
echo "Done. Restart Vesktop to see it."

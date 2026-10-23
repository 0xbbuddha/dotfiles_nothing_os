#!/usr/bin/env bash
# Update an installed Nothing rice from this checkout, file by file.
#
# Copies every tracked file of the shell, the scripts, the Hyprland config
# tree, the bundled wallpapers and the .desktop entries that differs from
# what is installed, after copying each one it replaces into a dated
# backup folder, with a rollback script next to them. Files you own are
# never in the list: custom.lua, local.lua, displays.lua, layout.lua,
# input.lua, accent.lua live directly in ~/.config/hypr, config.json in
# ~/.config/nothing. No sudo, no packages, no SDDM, no session change.
#
#   scripts/update-nothing.sh            # show, ask, back up, copy
#   scripts/update-nothing.sh --dry-run  # show only
#   scripts/update-nothing.sh --yes      # no question
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/nothing/backups/update-$STAMP"
DRY=0; YES=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --yes|-y) YES=1 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

die() { printf 'update-nothing: %s\n' "$*" >&2; exit 1; }

QS="$CONF/quickshell/nothing"
[[ -d "$QS" ]] || die "$QS does not exist: Nothing is not installed here. Use ./install (read it first)."
[[ -L "$QS" ]] && die "$QS is a symlink to $(readlink -f "$QS"); update that checkout instead."
[[ -f "$CONF/hypr/hyprland.lua" ]] || die "$CONF/hypr/hyprland.lua missing: Hyprland is not on this rice's Lua config."

# repo prefix -> installed prefix (the same places install-config.sh uses)
map_dest() {
    case "$1" in
        quickshell/nothing/*) echo "$QS/${1#quickshell/nothing/}" ;;
        scripts/*)            echo "$CONF/scripts/${1#scripts/}" ;;
        hypr/hyprland/*)      echo "$CONF/hypr/hyprland/${1#hypr/hyprland/}" ;;
        hypr/wallpapers/*)    echo "$CONF/hypr/wallpapers/${1#hypr/wallpapers/}" ;;
        hypr/hyprland.lua|hypr/hypridle.conf|hypr/lockstatus.sh|hypr/passthrough.lua|hypr/wallpaper.png)
                              echo "$CONF/hypr/${1#hypr/}" ;;
        applications/*.desktop) echo "$DATA/applications/${1#applications/}" ;;
        *) return 1 ;;
    esac
}

new=(); changed=()
while IFS= read -r -d '' f; do
    dst="$(map_dest "$f")" || continue
    if [[ ! -e "$dst" ]]; then new+=("$f")
    elif ! cmp -s "$ROOT/$f" "$dst"; then changed+=("$f"); fi
done < <(git -C "$ROOT" ls-files -z -- quickshell/nothing scripts hypr applications | sort -zu)

echo "Checkout: $ROOT ($(git -C "$ROOT" rev-parse --abbrev-ref HEAD) @ $(git -C "$ROOT" rev-parse --short HEAD))"
echo "${#new[@]} new file(s), ${#changed[@]} changed file(s)."
if (( ${#changed[@]} )); then
    echo "Replaced (each one backed up first):"
    printf '  %s\n' "${changed[@]}"
fi
if (( ${#new[@]} )); then
    echo "Added:"
    printf '  %s\n' "${new[@]}" | head -40
    (( ${#new[@]} > 40 )) && echo "  ... and $(( ${#new[@]} - 40 )) more"
fi
(( ${#new[@]} + ${#changed[@]} == 0 )) && { echo "Already up to date."; exit 0; }
(( DRY )) && { echo "Dry run: nothing written."; exit 0; }

if (( ! YES )); then
    read -r -p "Back up and update these files? [y/N] " ans
    [[ "$ans" == [yYoO]* ]] || { echo "Nothing changed."; exit 0; }
fi

mkdir -p "$BACKUP"
ROLLBACK="$BACKUP/rollback.sh"
printf '#!/usr/bin/env bash\n# Undo update-nothing.sh of %s\nset -e\n' "$STAMP" > "$ROLLBACK"
[[ -f "$CONF/nothing/config.json" ]] && cp -a "$CONF/nothing/config.json" "$BACKUP/config.json"

for f in "${changed[@]}" "${new[@]}"; do
    dst="$(map_dest "$f")"
    if [[ -e "$dst" ]]; then
        rel="${dst#"$HOME"/}"
        # Once: the first copy is the one that was installed.
        if [[ ! -e "$BACKUP/$rel" ]]; then
            mkdir -p "$BACKUP/$(dirname "$rel")"
            cp -a "$dst" "$BACKUP/$rel"
            printf 'cp -a %q %q\n' "$BACKUP/$rel" "$dst" >> "$ROLLBACK"
        fi
    else
        printf 'rm -f %q\n' "$dst" >> "$ROLLBACK"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$ROOT/$f" "$dst.tmp-$STAMP" && mv "$dst.tmp-$STAMP" "$dst"
done
chmod +x "$ROLLBACK"

command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" 2>/dev/null || true

echo ""
echo "Updated. Backup and rollback: $BACKUP"
echo "  undo with: $ROLLBACK"
echo "Quickshell reloads the shell on its own; run 'hyprctl reload' for keybinds and input."

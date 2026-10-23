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
#   scripts/update-nothing.sh --force    # also replace files edited by hand
#
# A file you edited by hand (its content matches no version this repo ever
# had) is merged, not replaced: its closest version in the repo's history
# is taken as what you started from, and your edit is replayed onto the new
# version (git merge-file). Only if both touched the same lines does the run
# stop and name the file; --force then replaces it (backed up). Extra files
# you added to the shell (a bar item of your own) are listed and left alone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/nothing/backups/update-$STAMP"
DRY=0; YES=0; FORCE=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --force) FORCE=1 ;;
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
        applications/servicemenus/*.desktop)
                              echo "$DATA/kio/servicemenus/${1#applications/servicemenus/}" ;;
        applications/*.desktop) echo "$DATA/applications/${1#applications/}" ;;
        *) return 1 ;;
    esac
}

# Every content this path ever had in the repo's history, as blob ids.
known_blobs() {
    git -C "$ROOT" log --all --format= --raw --no-abbrev -- "$1" 2>/dev/null \
        | awk '{ print $3; print $4 }' | sort -u
}

new=(); changed=(); edited=()
while IFS= read -r -d '' f; do
    dst="$(map_dest "$f")" || continue
    # Tracked but deleted in the working tree (an uncommitted change).
    [[ -f "$ROOT/$f" ]] || continue
    if [[ ! -e "$dst" ]]; then new+=("$f")
    elif ! cmp -s "$ROOT/$f" "$dst"; then
        changed+=("$f")
        blob="$(git -C "$ROOT" hash-object -- "$dst")"
        known_blobs "$f" | grep -qx "$blob" || edited+=("$f")
    fi
done < <(git -C "$ROOT" ls-files -z -- quickshell/nothing scripts hypr applications | sort -zu)

# Your own additions to the shell: not ours to touch, worth knowing about.
extra=()
while IFS= read -r -d '' x; do
    rel="quickshell/nothing/${x#"$QS"/}"
    git -C "$ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 || extra+=("$rel")
done < <(find "$QS" -type f -name '*.qml' -print0)

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
if (( ${#extra[@]} )); then
    echo "Your own files in the shell (kept as they are):"
    printf '  %s\n' "${extra[@]}"
fi
# Hand edits: replay them onto the new version.
MERGE="$(mktemp -d)"
trap 'rm -rf "$MERGE"' EXIT
declare -A merged=()
conflicts=()
for f in "${edited[@]}"; do
    dst="$(map_dest "$f")"
    best=""; bestn=-1
    for b in $(known_blobs "$f"); do
        git -C "$ROOT" cat-file -e "$b" 2>/dev/null || continue
        n=$(diff <(git -C "$ROOT" cat-file blob "$b") "$dst" | grep -c '^[<>]' || true)
        if (( bestn < 0 || n < bestn )); then best="$b"; bestn=$n; fi
    done
    key="${f//\//_}"
    if [[ -n "$best" ]]; then
        git -C "$ROOT" cat-file blob "$best" > "$MERGE/$key.base"
        cp "$dst" "$MERGE/$key.mine"
        if git merge-file -p "$MERGE/$key.mine" "$MERGE/$key.base" "$ROOT/$f" > "$MERGE/$key.out" 2>/dev/null; then
            merged["$f"]="$MERGE/$key.out"
            continue
        fi
    fi
    conflicts+=("$f")
done

if (( ${#merged[@]} )); then
    echo ""
    echo "Edited by hand, your edits carried over onto the new version:"
    for f in "${!merged[@]}"; do echo "  $(map_dest "$f")"; done
fi
if (( ${#conflicts[@]} )); then
    echo ""
    echo "Edited by hand where the new version changed the same lines:"
    for f in "${conflicts[@]}"; do echo "  $(map_dest "$f")"; done
    if (( ! FORCE )); then
        echo "Stopping so those edits are not lost. Compare with:"
        for f in "${conflicts[@]}"; do echo "  diff -u $ROOT/$f $(map_dest "$f")"; done
        echo "then carry your change into this checkout, or re-run with --force (backed up)."
        exit 1
    fi
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

# Staged next to the config first, then moved in one quick pass: Quickshell
# reloads on every change, and a reload in the middle of a slow copy sees
# half a shell ("X is not a type") and stays on that failure.
STAGE="$CONF/.nothing-update-$STAMP"
mkdir -p "$STAGE"
trap 'rm -rf "$STAGE" "$MERGE"' EXIT
i=0
for f in "${changed[@]}" "${new[@]}"; do
    i=$((i + 1))
    cp "${merged[$f]:-$ROOT/$f}" "$STAGE/$i"
    # A merge result is written by redirection (0644): the mode is the
    # repo file's, or a merged script would lose its executable bit.
    chmod --reference="$ROOT/$f" "$STAGE/$i"
done

i=0
for f in "${changed[@]}" "${new[@]}"; do
    i=$((i + 1))
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
    mv "$STAGE/$i" "$dst"
done
chmod +x "$ROLLBACK"

command -v update-desktop-database >/dev/null && update-desktop-database "$DATA/applications" 2>/dev/null || true

# Files an earlier version of this branch installed and no longer ships.
# "Set as wallpaper" was a MIME handler for pictures, which could become
# the default image opener; it is a Dolphin service menu now.
for old in "$DATA/applications/nothing-set-wallpaper.desktop"; do
    [[ -e "$old" ]] || continue
    rel="${old#"$HOME"/}"
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -a "$old" "$BACKUP/$rel"
    printf 'cp -a %q %q\n' "$BACKUP/$rel" "$old" >> "$ROLLBACK"
    rm -f "$old"
    echo "removed (obsolete): $old"
done

# One clean reload with every file in place.
sleep 1
touch "$QS/shell.qml"

echo ""
echo "Updated. Backup and rollback: $BACKUP"
echo "  undo with: $ROLLBACK"
echo "Quickshell reloads the shell on its own; run 'hyprctl reload' for keybinds and input."

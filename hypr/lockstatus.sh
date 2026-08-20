#!/usr/bin/env bash
# Status line shown at the bottom of the lock screen.
set -uo pipefail

parts=()

# Battery
for b in /sys/class/power_supply/BAT*; do
    [[ -r "$b/capacity" ]] || continue
    cap="$(cat "$b/capacity")"
    st="$(cat "$b/status" 2>/dev/null)"
    icon="BAT"
    [[ "$st" == "Charging" ]] && icon="CHG"
    parts+=("$icon $cap%")
    break
done

# Network
if command -v nmcli >/dev/null 2>&1; then
    net="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2!="loopback"{print $1; exit}')"
    [[ -n "$net" ]] && parts+=("$net")
fi

# Now playing
if command -v playerctl >/dev/null 2>&1; then
    if [[ "$(playerctl status 2>/dev/null)" == "Playing" ]]; then
        t="$(playerctl metadata title 2>/dev/null | cut -c1-38)"
        [[ -n "$t" ]] && parts+=("$t")
    fi
fi

# IFS only takes a single character: assemble by hand.
out=""
for p in "${parts[@]}"; do
    [[ -n "$out" ]] && out+="  \u00b7  "
    out+="$p"
done
printf '%b' "$out"

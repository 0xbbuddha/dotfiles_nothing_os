#!/usr/bin/env bash
# On-machine checks for the SUPER+P Light page. No sudo, no packages.
#
#   scripts/test-display-light.sh           # read-only: versions, mapping, values
#   scripts/test-display-light.sh --write   # also: one DDC write per monitor with
#                                           # read-back, hyprsunset round trip,
#                                           # everything put back afterwards
#
# Writes are bounded: one brightness change (and its restore) on monitors
# that accept writes; on a monitor that refuses, a single write of the value
# it already has, so a refusal changes nothing you can see.
set -uo pipefail

WRITE=0
[[ "${1:-}" == "--write" ]] && WRITE=1
SHELL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/nothing"
pass=0; fail=0; skip=0
ok()   { printf '  PASS  %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }
nope() { printf '  SKIP  %s\n' "$*"; skip=$((skip+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

echo "== versions"
for c in "hyprctl version" "qs --version" "ddcutil --version" "hyprsunset --version"; do
    b=${c%% *}
    if have "$b"; then printf '  %-12s %s\n' "$b" "$($c 2>&1 | grep -m1 -E '[0-9]+\.[0-9]+' )"; else printf '  %-12s missing\n' "$b"; fi
done

echo "== processes"
n_qs=$(pgrep -fc 'q(uick)?s(hell)? .*quickshell/nothing' || true)
n_hs=$(pgrep -xc hyprsunset || true)
[[ "$n_qs" == 1 ]] && ok "one Nothing shell" || bad "Nothing shell instances: $n_qs"
[[ "$n_hs" -le 1 ]] && ok "hyprsunset instances: $n_hs" || bad "duplicate hyprsunset: $n_hs"

echo "== outputs (Hyprland) vs DDC/CI (ddcutil)"
have hyprctl && hyprctl -j monitors all | python3 -c '
import json,sys
for m in json.load(sys.stdin):
    print("  %-10s %-28s %sx%s@%.0f vrr=%s fmt=%s cm=%s" % (m["name"], (m.get("make","")+" "+m.get("model","")).strip(),
          m["width"], m["height"], m["refreshRate"], m.get("vrr"), m.get("currentFormat","?"), m.get("colorManagementPreset","n/a")))'
declare -A BUS
if have ddcutil; then
    det="$(ddcutil detect 2>&1)"
    while read -r bus conn; do BUS[$conn]=$bus; done < <(printf '%s\n' "$det" | awk '
        /^(Display [0-9]+|Invalid display)/ {inv = ($1=="Invalid")}
        /I2C bus:/ {split($3,a,"-"); bus=a[2]}
        /DRM[_ ]connector:/ {c=$2; sub(/^card[0-9]+-/,"",c); if (!inv) print bus, c}')
    for conn in "${!BUS[@]}"; do
        printf '  %-10s -> i2c-%s\n' "$conn" "${BUS[$conn]}"
        if have hyprctl && hyprctl -j monitors all | grep -q "\"name\": \"$conn\""; then ok "$conn matched to a Hyprland output"; else bad "$conn not a Hyprland output"; fi
    done
    (( ${#BUS[@]} )) || bad "no DDC/CI monitor: $(printf '%s\n' "$det" | grep -m2 -iE 'i2c|permission|fail')"
else
    nope "ddcutil not installed"
fi

read_b() { ddcutil --bus "$1" getvcp 10 --brief 2>/dev/null | awk '/^VCP 10 C/ {print $4, $5}'; }

echo "== brightness"
for conn in "${!BUS[@]}"; do
    bus=${BUS[$conn]}
    v=$(read_b "$bus")
    if [[ -z "$v" ]]; then bad "$conn: getvcp 10 failed"; continue; fi
    cur=${v% *}; max=${v#* }
    ok "$conn: brightness $cur / $max"
    (( WRITE )) || continue
    caps="$(ddcutil --bus "$bus" capabilities 2>/dev/null | grep -m1 -E 'Feature: 10|^ *10 ')"
    [[ -n "$caps" ]] && ok "$conn advertises feature 0x10" || nope "$conn: 0x10 not in capabilities (may still work)"
    # Writability first, with no visible change: write what it already has.
    out=$(ddcutil --bus "$bus" setvcp 10 "$cur" 2>&1); rc=$?
    if (( rc != 0 )); then
        bad "$conn rejects writes (exit $rc): $(printf '%s' "$out" | grep -m1 -oE 'DDCRC_[A-Z_]+|.{0,80}')"
        continue
    fi
    tgt=$(( cur >= 20 ? cur - 10 : cur + 10 ))
    ddcutil --bus "$bus" --noverify setvcp 10 "$tgt" >/dev/null 2>&1
    sleep 0.4; r1=$(read_b "$bus"); r1=${r1% *}
    sleep 1.2; r2=$(read_b "$bus"); r2=${r2% *}
    if [[ "$r1" == "$tgt" ]]; then ok "$conn: set $tgt, read back $r1 after 0.4 s"
    elif [[ "$r2" == "$tgt" ]]; then ok "$conn: set $tgt, read back $r2 only after 1.6 s (slow; the panel waits for this)"
    else bad "$conn: set $tgt, read back $r1 then $r2"; fi
    ddcutil --bus "$bus" --noverify setvcp 10 "$cur" >/dev/null 2>&1; sleep 0.6
    r=$(read_b "$bus"); [[ "${r% *}" == "$cur" ]] && ok "$conn: restored to $cur" || bad "$conn: restore read ${r% *}, wanted $cur"
done

echo "== hyprsunset"
if ! pidof hyprsunset >/dev/null; then
    nope "hyprsunset not running (the panel starts it on first use)"
elif (( WRITE )); then
    k0=$(hyprctl hyprsunset temperature); i0=$(hyprctl hyprsunset identity get); g0=$(hyprctl hyprsunset gamma)
    echo "  start: temperature=$k0 identity=$i0 gamma=$g0"
    hyprctl hyprsunset temperature 3500 >/dev/null; sleep 0.3
    [[ "$(hyprctl hyprsunset temperature)" == 3500 && "$(hyprctl hyprsunset identity get)" == false ]] && ok "temperature 3500 live" || bad "temperature did not apply"
    hyprctl hyprsunset gamma 80 >/dev/null; hyprctl hyprsunset identity >/dev/null; sleep 0.3
    [[ "$(hyprctl hyprsunset identity get)" == true && "$(hyprctl hyprsunset gamma)" == 80* ]] && ok "identity keeps gamma (neutral colours, dim kept)" || bad "identity/gamma: $(hyprctl hyprsunset identity get) $(hyprctl hyprsunset gamma)"
    hyprctl hyprsunset gamma "${g0%%.*}" >/dev/null
    if [[ "$i0" == true ]]; then hyprctl hyprsunset identity >/dev/null; else hyprctl hyprsunset temperature "$k0" >/dev/null; fi
    sleep 0.3; ok "restored: temperature=$(hyprctl hyprsunset temperature) identity=$(hyprctl hyprsunset identity get) gamma=$(hyprctl hyprsunset gamma)"
else
    ok "running: temperature=$(hyprctl hyprsunset temperature) identity=$(hyprctl hyprsunset identity get) gamma=$(hyprctl hyprsunset gamma)"
fi

echo "== shell IPC and keybinds"
if have qs && [[ -d "$SHELL_DIR" ]]; then
    s=$(qs -p "$SHELL_DIR" ipc call nightlight status 2>&1) && ok "ipc nightlight status: ${s:-<empty>}" || bad "ipc nightlight: $s"
    qs -p "$SHELL_DIR" ipc show 2>/dev/null | grep -q 'function light' && ok "ipc displays.light present" || bad "displays.light missing (deployed?)"
fi
if have hyprctl; then
    hyprctl -j binds | python3 -c '
import json,sys
b=json.load(sys.stdin)
p=[x for x in b if x.get("modmask")==64 and x.get("key","").lower()=="p"]
n=[x for x in b if x.get("modmask")==72 and x.get("key","").lower()=="b"]
print("  SUPER+P     x%d -> %s" % (len(p), "; ".join(x.get("arg","") for x in p)))
print("  SUPER+ALT+B x%d -> %s" % (len(n), "; ".join(x.get("arg","") for x in n)))
sys.exit(0 if len(p)==1 and len(n)<=1 else 1)' && ok "no duplicate SUPER+P / SUPER+ALT+B" || bad "duplicate binding"
fi

echo "== input and power"
f="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/input.lua"
if [[ -f "$f" ]]; then
    out=$(hyprctl eval "(function() $(sed '/^--/d' "$f") return \"ok\" end)()" 2>&1)
    [[ "$out" == ok ]] && ok "input.lua accepted by Hyprland" || bad "input.lua refused: $out"
else
    ok "input.lua absent (Settings > Input never used: input untouched)"
fi
if have powerprofilesctl && p=$(powerprofilesctl get 2>/dev/null); then ok "power profile: $p"; else nope "no power-profiles-daemon answering"; fi

echo "== $pass passed, $fail failed, $skip skipped"
(( fail == 0 ))

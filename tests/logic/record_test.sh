#!/usr/bin/env bash
# Tests record.sh's mix_both(): on a partial module-load failure it must
# tear down whatever did load and fall back to a single source, never
# report "both" while actually recording less.
set -euo pipefail

RECORD_SH="$1"
WORK="$(mktemp -d)"
FAKE_BIN="$WORK/bin"
mkdir -p "$FAKE_BIN"
export XDG_RUNTIME_DIR="$WORK"
trap 'rm -rf "$WORK"' EXIT

UNLOAD_LOG="$WORK/unloaded"
: > "$UNLOAD_LOG"
export UNLOAD_LOG

# Fake pactl: the sink and the first loopback load fine, the mic
# loopback (the third load-module call) fails to load.
cat > "$FAKE_BIN/pactl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "load-module module-null-sink"*) echo 10 ;;
  "load-module module-loopback source=MONSRC"*) echo 11 ;;
  "load-module module-loopback source=MICSRC"*) exit 1 ;;
  "unload-module "*) echo "$2" >> "$UNLOAD_LOG"; exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FAKE_BIN/pactl"
export PATH="$FAKE_BIN:$PATH"

# Sourcing with "status" hits the harmless status branch (a pgrep check,
# no pactl/audio touched) after defining mix_both() and friends.
source "$RECORD_SH" status >/dev/null 2>&1

SRC="$(mix_both MONSRC MICSRC)"
[[ "$SRC" == "MONSRC" ]] || { echo "FAIL: expected fallback to MONSRC, got '$SRC'"; exit 1; }
[[ ! -f "$MODFILE" ]] || { echo "FAIL: MODFILE must not be written on a partial failure"; exit 1; }
grep -qx 10 "$UNLOAD_LOG" || { echo "FAIL: the null-sink module (10) was never unloaded"; exit 1; }
grep -qx 11 "$UNLOAD_LOG" || { echo "FAIL: the loaded loopback module (11) was never unloaded"; exit 1; }

echo "record: both-audio partial-failure fallback ok"

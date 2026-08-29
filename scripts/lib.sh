# shellcheck shell=bash
# Helpers for ./install. Sourced, not executed.
#
# The look follows Nothing OS: black ground, white type, one red accent
# (#d71921) and nothing else. Colour is decoration only, so every message
# still reads correctly with NO_COLOR set or piped to a file.

if [[ -z "${NOTHING_ROOT:-}" ]]; then
    NOTHING_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ── Palette ───────────────────────────────────────────────────────────
# Truecolor where the terminal says it can, 256 colours otherwise, and
# nothing at all when the output is not a terminal or NO_COLOR is set.
# A rice installer that dumps escape codes into a log is its own bug.
_colour_depth() {
    [[ -n "${NO_COLOR:-}" ]] && { echo none; return; }
    [[ -t 1 ]] || { echo none; return; }
    case "${TERM:-dumb}" in dumb|"") echo none; return ;; esac
    case "${COLORTERM:-}" in truecolor|24bit) echo true; return ;; esac
    [[ "$(tput colors 2>/dev/null || echo 0)" -ge 256 ]] && { echo 256; return; }
    echo basic
}

case "$(_colour_depth)" in
    true)
        RED=$'\033[38;2;215;25;33m'
        FG=$'\033[38;2;255;255;255m'
        DIM=$'\033[38;2;138;138;138m'
        FAINT=$'\033[38;2;69;69;69m'
        BLD=$'\033[1m'; RST=$'\033[0m'
        ;;
    256)
        RED=$'\033[38;5;160m'; FG=$'\033[38;5;255m'
        DIM=$'\033[38;5;245m'; FAINT=$'\033[38;5;240m'
        BLD=$'\033[1m'; RST=$'\033[0m'
        ;;
    basic)
        RED=$'\033[31m'; FG=$'\033[37m'
        DIM=$'\033[2m'; FAINT=$'\033[2m'
        BLD=$'\033[1m'; RST=$'\033[0m'
        ;;
    *)
        RED=""; FG=""; DIM=""; FAINT=""; BLD=""; RST=""
        ;;
esac

NOCONFIRM=false

# ── Dot matrix ────────────────────────────────────────────────────────
# Nothing's wordmark is a dot grid, so the banner is one too: lit dots in
# white, unlit dots left visible in faint grey, which is what makes it read
# as a matrix rather than as ASCII art. 41 columns wide, so it fits an
# 80-column terminal with room to spare.
_GLYPH_N="10001 11001 10101 10011 10001"
_GLYPH_O="01110 10001 10001 10001 01110"
_GLYPH_T="11111 00100 00100 00100 00100"
_GLYPH_H="10001 10001 11111 10001 10001"
_GLYPH_I="11111 00100 00100 00100 11111"
_GLYPH_G="01110 10000 10011 10001 01110"

_utf8() { [[ "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" == *[Uu][Tt][Ff]* ]]; }

banner() {
    local on off row letter bits line
    if _utf8; then on="●"; off="·"; else on="#"; off="."; fi
    for row in 0 1 2 3 4; do
        line=""
        for letter in N O T H I N G; do
            local -n g="_GLYPH_$letter"
            # shellcheck disable=SC2206
            local rows=($g)
            bits="${rows[$row]}"
            local i ch
            for ((i = 0; i < ${#bits}; i++)); do
                ch="${bits:i:1}"
                if [[ "$ch" == 1 ]]; then
                    line+="${FG}${on}${RST}"
                else
                    line+="${FAINT}${off}${RST}"
                fi
            done
            line+="${FAINT}${off}${RST}"
        done
        printf '  %s\n' "$line"
    done
}

# Letter-spaced small caps, the Nothing label treatment.
track() {
    local s="$1" out="" i
    for ((i = 0; i < ${#s}; i++)); do
        out+="${s:i:1}"
        (( i < ${#s} - 1 )) && out+=" "
    done
    printf '%s' "$out"
}

rule() {
    local w="${COLUMNS:-0}" ch
    (( w == 0 )) && w="$(tput cols 2>/dev/null || echo 72)"
    (( w > 72 )) && w=72
    (( w < 20 )) && w=20
    if _utf8; then ch="─"; else ch="-"; fi
    local out="" i
    for ((i = 0; i < w - 2; i++)); do out+="$ch"; done
    printf '%s%s%s\n' "$FAINT" "$out" "$RST"
}

# ── Messages ──────────────────────────────────────────────────────────
# Red is the accent, never a status: it marks the step numbers and a hard
# failure, and nothing in between.
# step <number> <title>. The number is passed in, never counted here:
# each stage of the installer runs in its own process, so a counter kept
# in a variable would restart at one in every one of them.
step() {
    printf '\n'
    rule
    printf '  %s%02d%s   %s%s%s\n' "$RED" "$1" "$RST" \
        "$BLD" "$(track "$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]')")" "$RST"
    rule
}

log()  { printf '  %s·%s %s\n' "$DIM" "$RST" "$*"; }
ok()   { printf '  %s●%s %s\n' "$FG" "$RST" "$*"; }
warn() { printf '  %s!%s %s\n' "$DIM" "$RST" "$*" >&2; }
die()  { printf '  %s✕%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

# A labelled value, aligned: "REPO   /path".
field() { printf '  %s%-9s%s %s\n' "$DIM" "$1" "$RST" "$2"; }

need_root_denied() {
    if [[ ${EUID} -eq 0 ]]; then
        die "Do not run this as root. The script will ask sudo when it needs it."
    fi
}

run() {
    printf '    %s$ %s%s\n' "$FAINT" "$*" "$RST"
    "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

ask_yn() {
    local prompt=$1 default=${2:-y} reply
    if [[ "$NOCONFIRM" == true ]]; then
        [[ "$default" == y ]]
        return
    fi
    if [[ "$default" == y ]]; then
        read -r -p "  ${RED}?${RST} ${prompt} ${DIM}[Y/n]${RST} " reply
        [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
    else
        read -r -p "  ${RED}?${RST} ${prompt} ${DIM}[y/N]${RST} " reply
        [[ "$reply" =~ ^[Yy] ]]
    fi
}

pause() {
    [[ "$NOCONFIRM" == true ]] && return 0
    read -r -p "  ${DIM}Enter to continue, Ctrl-C to abort.${RST} "
}

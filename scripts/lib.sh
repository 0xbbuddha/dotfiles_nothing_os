# Helpers for ./install. Sourced, not executed.
# Style is close to illogical-impulse: print the command, then run it.

if [[ -z "${NOTHING_ROOT:-}" ]]; then
    NOTHING_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

RED=$'\033[31m'
YEL=$'\033[33m'
CYN=$'\033[36m'
DIM=$'\033[2m'
BLD=$'\033[1m'
RST=$'\033[0m'

ASK=true
NOCONFIRM=false

log()  { printf '%s→%s %s\n' "$CYN" "$RST" "$*"; }
ok()   { printf '%s✓%s %s\n' "$CYN" "$RST" "$*"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*" >&2; exit 1; }

need_root_denied() {
    if [[ ${EUID} -eq 0 ]]; then
        die "Do not run this as root. The script will ask sudo when it needs it."
    fi
}

run() {
    printf '%s$%s %s\n' "$DIM" "$RST" "$*"
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
        read -r -p "  ${prompt} [Y/n] " reply
        [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
    else
        read -r -p "  ${prompt} [y/N] " reply
        [[ "$reply" =~ ^[Yy] ]]
    fi
}

pause() {
    [[ "$NOCONFIRM" == true ]] && return 0
    read -r -p "  Press Enter to continue, Ctrl-C to abort. "
}

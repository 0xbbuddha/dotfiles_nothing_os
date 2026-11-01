FALLBACK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_ROOT="$(cd -- "$FALLBACK_DIR/../.." && pwd)"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FLAG="$RUNTIME_DIR/nothing-locked"
FALLBACK_GUARD="$RUNTIME_DIR/nothing-fallback-lock.lock"

shell_dir() {
    printf '%s\n' "${NOTHING_SHELL_DIR:-$SCRIPTS_ROOT/quickshell/nothing}"
}

is_secure() {
    [ "$(timeout 1 qs -p "$1" ipc call lock secure 2>/dev/null)" = "true" ]
}

wait_secure() {
    local dir="$1" deadline=$(( SECONDS + $2 ))
    while (( SECONDS <= deadline )); do
        is_secure "$dir" && return 0
        sleep 0.1
    done
    return 1
}

fallback_running() {
    ! flock -n "$FALLBACK_GUARD" true 2>/dev/null
}

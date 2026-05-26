#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="${VICE_MAC_DIST_DIR:-$MACOS_DIR/dist}"
SMOKE_APPS="${VICE_MAC_SMOKE_APPS:-x64sc xvic xpet xplus4 xc16 xc232 xv364 x128}"
SMOKE_TIMEOUT="${VICE_MAC_SMOKE_TIMEOUT:-35}"
SMOKE_ATTEMPTS="${VICE_MAC_SMOKE_ATTEMPTS:-2}"
KEEP_LOGS="${VICE_MAC_SMOKE_KEEP_LOGS:-0}"
DMG_PATH="${1:-}"

WORK_DIR=""
MOUNT_DIR=""
APP_PID=""
CURRENT_APP=""
CURRENT_STDOUT_LOG=""
CURRENT_STDERR_LOG=""
CURRENT_FAILURE=""

fail() {
    echo "DMG smoke test failed: $*" >&2
    exit 1
}

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

print_log() {
    local label="$1"
    local path="$2"

    if [[ -s "$path" ]]; then
        echo "----- $label -----" >&2
        tail -200 "$path" >&2 || true
    fi
}

cleanup() {
    local status=$?

    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
        kill "$APP_PID" >/dev/null 2>&1 || true
        wait "$APP_PID" >/dev/null 2>&1 || true
    fi

    if [[ -n "$MOUNT_DIR" ]]; then
        hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force -quiet >/dev/null 2>&1 || true
    fi

    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        if [[ "$KEEP_LOGS" == "1" ]]; then
            echo "DMG smoke test logs kept in $WORK_DIR" >&2
        else
            rm -rf "$WORK_DIR"
        fi
    fi

    exit "$status"
}

resolve_dmg_path() {
    local found_count

    if [[ -n "$DMG_PATH" ]]; then
        echo "$DMG_PATH"
        return
    fi

    shopt -s nullglob
    local dmgs=("$DIST_DIR"/VICE-Mac-*-arm64.dmg)
    shopt -u nullglob

    found_count="${#dmgs[@]}"
    if [[ "$found_count" -eq 0 ]]; then
        fail "no VICE Mac DMG found in $DIST_DIR"
    elif [[ "$found_count" -gt 1 ]]; then
        printf 'Multiple VICE Mac DMGs found in %s:\n' "$DIST_DIR" >&2
        printf '  %s\n' "${dmgs[@]}" >&2
        fail "pass the DMG path explicitly"
    fi

    echo "${dmgs[0]}"
}

assert_no_loader_errors() {
    local loader_error_pattern='VICE Mac: unable to load|Library not loaded|not valid for use in process|Symbol not found|dyld|dlopen'

    if [[ -s "$CURRENT_STDERR_LOG" ]] && grep -E "$loader_error_pattern" "$CURRENT_STDERR_LOG" >/dev/null 2>&1; then
        print_log "$CURRENT_APP stderr" "$CURRENT_STDERR_LOG"
        fail "$CURRENT_APP emitted dynamic loader/startup errors"
    fi
}

run_app_smoke_test() {
    local app="$1"
    local attempt

    for ((attempt = 1; attempt <= SMOKE_ATTEMPTS; attempt++)); do
        if run_app_smoke_test_attempt "$app" "$attempt"; then
            echo "DMG smoke test passed for $app"
            return
        fi

        if [[ "$attempt" -ge "$SMOKE_ATTEMPTS" ]]; then
            fail "$CURRENT_FAILURE"
        fi

        echo "Retrying $app smoke test after failed attempt $attempt/$SMOKE_ATTEMPTS" >&2
        sleep 2
    done
}

run_app_smoke_test_attempt() {
    local app="$1"
    local attempt="$2"
    local app_bundle
    local app_executable
    local status
    local timeout_deadline
    local wait_timeout

    CURRENT_APP="$app"
    CURRENT_STDOUT_LOG="$WORK_DIR/$app.attempt-$attempt.stdout.log"
    CURRENT_STDERR_LOG="$WORK_DIR/$app.attempt-$attempt.stderr.log"
    CURRENT_FAILURE=""
    app_bundle="$MOUNT_DIR/$app.app"
    app_executable="$app_bundle/Contents/MacOS/$app"

    [[ -d "$app_bundle" ]] || fail "app bundle is missing from DMG: $app.app"
    [[ -x "$app_executable" ]] || fail "app executable is missing or not executable: $app_executable"

    echo "Smoke testing $app_executable"
    "$app_executable" --vice-mac-smoke-test --vice-mac-smoke-timeout "$SMOKE_TIMEOUT" >"$CURRENT_STDOUT_LOG" 2>"$CURRENT_STDERR_LOG" &
    APP_PID=$!

    wait_timeout=$((SMOKE_TIMEOUT + 15))
    timeout_deadline=$((SECONDS + wait_timeout))
    while kill -0 "$APP_PID" >/dev/null 2>&1; do
        if [[ "$SECONDS" -ge "$timeout_deadline" ]]; then
            kill "$APP_PID" >/dev/null 2>&1 || true
            wait "$APP_PID" >/dev/null 2>&1 || true
            APP_PID=""
            print_log "$app stdout" "$CURRENT_STDOUT_LOG"
            print_log "$app stderr" "$CURRENT_STDERR_LOG"
            CURRENT_FAILURE="$app did not exit from smoke-test mode within ${wait_timeout}s"
            return 1
        fi

        sleep 1
    done

    set +e
    wait "$APP_PID"
    status=$?
    set -e
    APP_PID=""

    if [[ "$status" -ne 0 ]]; then
        print_log "$app stdout" "$CURRENT_STDOUT_LOG"
        print_log "$app stderr" "$CURRENT_STDERR_LOG"
        CURRENT_FAILURE="$app smoke test exited with status $status"
        return 1
    fi

    assert_no_loader_errors

    if [[ -s "$CURRENT_STDERR_LOG" ]]; then
        echo "$app produced stderr during smoke test:" >&2
        print_log "$app stderr" "$CURRENT_STDERR_LOG"
    fi

    return 0
}

require_tool hdiutil "Install or restore the macOS command line tools."

DMG_PATH="$(resolve_dmg_path)"
[[ -f "$DMG_PATH" ]] || fail "DMG does not exist: $DMG_PATH"
[[ "$SMOKE_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || fail "VICE_MAC_SMOKE_ATTEMPTS must be a positive integer"

WORK_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/vice-macos-dmg-smoke.XXXXXX")"
MOUNT_DIR="$WORK_DIR/mount"
mkdir -p "$MOUNT_DIR"
trap cleanup EXIT INT TERM

echo "Mounting $DMG_PATH"
if ! hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -readonly -quiet; then
    fail "unable to mount $DMG_PATH"
fi

for app in $SMOKE_APPS; do
    run_app_smoke_test "$app"
done

echo "DMG smoke test passed for $DMG_PATH"

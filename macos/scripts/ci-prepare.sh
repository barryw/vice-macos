#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$PATH"

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

require_tool xcodebuild "Install the latest Xcode and select it with xcode-select."
require_tool hdiutil "hdiutil ships with macOS."
require_tool dos2unix "Install it with: brew install dos2unix"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "VICE Mac must be built on macOS." >&2
    exit 1
fi

metal_toolchain_installed() {
    xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q '^Status: installed$'
}

fetch_origin_history() {
    local is_shallow

    if ! git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
        return
    fi

    is_shallow="$(git -C "$REPO_ROOT" rev-parse --is-shallow-repository 2>/dev/null || echo false)"
    if [[ "$is_shallow" == "true" ]]; then
        git -C "$REPO_ROOT" fetch --tags --unshallow origin ||
            git -C "$REPO_ROOT" fetch --tags --deepen=5000 origin
        return
    fi

    git -C "$REPO_ROOT" fetch --tags origin
}

if [[ "${VICE_MAC_INSTALL_METAL_TOOLCHAIN:-1}" == "1" ]] && ! metal_toolchain_installed; then
    xcodebuild -downloadComponent MetalToolchain
fi

fetch_origin_history

if [[ "${VICE_MAC_CI_FETCH_UPSTREAM:-1}" == "1" ]]; then
    if ! git -C "$REPO_ROOT" remote get-url upstream >/dev/null 2>&1; then
        git -C "$REPO_ROOT" remote add upstream https://github.com/VICE-Team/svn-mirror.git
    fi

    git -C "$REPO_ROOT" fetch --no-tags upstream +refs/heads/main:refs/remotes/upstream/main ||
        git -C "$REPO_ROOT" fetch --no-tags --depth=1 upstream +refs/heads/main:refs/remotes/upstream/main
fi

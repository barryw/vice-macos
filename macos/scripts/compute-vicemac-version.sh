#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGURE_AC="$REPO_ROOT/vice/configure.ac"

# Accept and ignore --current for parity with the MCP release helper.
shift $# 2>/dev/null || true

if [[ ! -f "$CONFIGURE_AC" ]]; then
    echo "ERROR: $CONFIGURE_AC not found" >&2
    exit 1
fi

major="$(sed -n 's/^m4_define(vice_version_major, \([0-9][0-9]*\))/\1/p' "$CONFIGURE_AC")"
minor="$(sed -n 's/^m4_define(vice_version_minor, \([0-9][0-9]*\))/\1/p' "$CONFIGURE_AC")"
build="$(sed -n 's/^m4_define(vice_version_build, \([0-9][0-9]*\))/\1/p' "$CONFIGURE_AC")"

if [[ -z "$major" || -z "$minor" || -z "$build" ]]; then
    echo "ERROR: could not read VICE version from $CONFIGURE_AC" >&2
    exit 1
fi

git_sha="$(git -C "$REPO_ROOT" rev-parse --short=7 HEAD)"

echo "vice-mac-${major}.${minor}.${build}-${git_sha}-1"

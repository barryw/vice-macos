#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
DIST_DIR="${VICE_MAC_DIST_DIR:-$MACOS_DIR/dist}"

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

release_tag() {
    if [[ -n "${CI_COMMIT_TAG:-}" ]]; then
        echo "$CI_COMMIT_TAG"
        return
    fi

    git -C "$REPO_ROOT" describe --tags --exact-match 2>/dev/null || {
        echo "This step must run from a tagged commit." >&2
        exit 1
    }
}

github_repo_arg() {
    if [[ -n "${CI_REPO:-}" ]]; then
        echo "--repo=$CI_REPO"
    fi
}

require_tool gh "Install GitHub CLI with: brew install gh"

if [[ ! -d "$DIST_DIR" ]]; then
    echo "Release artifacts are missing at $DIST_DIR." >&2
    exit 1
fi

shopt -s nullglob
artifacts=("$DIST_DIR"/*.dmg)
if [[ -f "$DIST_DIR/SHA256SUMS.txt" ]]; then
    artifacts+=("$DIST_DIR/SHA256SUMS.txt")
fi
if [[ "${#artifacts[@]}" -eq 0 ]]; then
    echo "No release artifacts found in $DIST_DIR." >&2
    exit 1
fi

tag="$(release_tag)"
repo_arg="$(github_repo_arg)"
notes_file="$DIST_DIR/release-notes.md"

cat > "$notes_file" <<EOF
VICE Mac $tag

Apple Silicon macOS builds of the native VICE Mac apps.

Artifacts:
- DMG installer image
- SHA256 checksums
EOF

if ! gh release view "$tag" $repo_arg >/dev/null 2>&1; then
    gh release create "$tag" $repo_arg \
        --title "VICE Mac $tag" \
        --notes-file "$notes_file"
fi

gh release upload "$tag" $repo_arg --clobber "${artifacts[@]}"

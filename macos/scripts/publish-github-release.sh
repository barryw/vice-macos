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
    if [[ -n "${VICE_MAC_RELEASE_TAG:-}" ]]; then
        echo "$VICE_MAC_RELEASE_TAG"
        return
    fi

    if [[ -n "${CI_COMMIT_TAG:-}" ]]; then
        echo "$CI_COMMIT_TAG"
        return
    fi

    "$SCRIPT_DIR/compute-vicemac-version.sh"
}

github_repo_args() {
    if [[ -n "${CI_REPO:-}" ]]; then
        echo "--repo=$CI_REPO"
    fi
}

release_target_args() {
    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        echo "--target=$CI_COMMIT_SHA"
    fi
}

write_release_notes() {
    local tag="$1"
    local notes_file="$2"
    local previous_tag
    local notes

    previous_tag="$(git -C "$REPO_ROOT" tag -l 'vice-mac-*' --sort=-creatordate | grep -v "^$tag$" | head -1 || true)"

    if [[ -n "$previous_tag" ]]; then
        notes="$(git -C "$REPO_ROOT" log "$previous_tag..HEAD" --pretty=format:"- %s" --no-merges)"
    else
        notes="$(git -C "$REPO_ROOT" log --pretty=format:"- %s" --no-merges -20)"
    fi

    if [[ -z "$notes" ]]; then
        notes="- No changes since the previous VICE Mac release."
    fi

    cat > "$notes_file" <<EOF
Apple Silicon macOS builds of the native VICE Mac apps.

Artifacts:
- DMG installer image
- SHA256 checksums

Changes:
$notes
EOF
}

require_tool gh "Install GitHub CLI with: brew install gh"

git -C "$REPO_ROOT" fetch --tags origin >/dev/null 2>&1 || git -C "$REPO_ROOT" fetch --tags >/dev/null 2>&1 || true

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
if [[ "$tag" != vice-mac-* ]]; then
    echo "VICE Mac release tags must start with 'vice-mac-'." >&2
    echo "Refusing to publish release for tag '$tag'." >&2
    exit 1
fi

release_label="${tag#vice-mac-}"
notes_file="$DIST_DIR/release-notes.md"
repo_args=()
target_args=()

while IFS= read -r arg; do
    repo_args+=("$arg")
done < <(github_repo_args)

while IFS= read -r arg; do
    target_args+=("$arg")
done < <(release_target_args)

write_release_notes "$tag" "$notes_file"

if ! gh release view "$tag" "${repo_args[@]}" >/dev/null 2>&1; then
    gh release create "$tag" "${repo_args[@]}" "${target_args[@]}" \
        --title "VICE Mac $release_label" \
        --notes-file "$notes_file" \
        --draft
fi

gh release upload "$tag" "${repo_args[@]}" --clobber "${artifacts[@]}"
gh release edit "$tag" "${repo_args[@]}" \
    --title "VICE Mac $release_label" \
    --notes-file "$notes_file" \
    --draft=false \
    --prerelease=false \
    --latest

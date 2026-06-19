#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/publish-github-release.sh"

fail() {
    echo "release notes test failed: $*" >&2
    exit 1
}

commit_file() {
    local repo="$1"
    local path="$2"
    local content="$3"
    local subject="$4"

    mkdir -p "$(dirname "$repo/$path")"
    printf '%s\n' "$content" > "$repo/$path"
    git -C "$repo" add "$path"
    git -C "$repo" commit -q -m "$subject"
}

assert_contains() {
    local file="$1"
    local expected="$2"

    grep -Fq "$expected" "$file" || fail "expected notes to contain: $expected"
}

assert_not_contains() {
    local file="$1"
    local unexpected="$2"

    if grep -Fq "$unexpected" "$file"; then
        fail "notes should not contain: $unexpected"
    fi
}

tmp_repo="$(mktemp -d "${TMPDIR:-/tmp}/vicemac-release-notes-test.XXXXXX")"
trap 'rm -rf "$tmp_repo"' EXIT

git -C "$tmp_repo" init -q
git -C "$tmp_repo" config user.email "test@example.invalid"
git -C "$tmp_repo" config user.name "VICE Mac Test"
main_branch="$(git -C "$tmp_repo" branch --show-current)"

commit_file "$tmp_repo" "macos/ViceMac/Seed.swift" "seed" "Seed native app"
git -C "$tmp_repo" tag vice-mac-0.1

commit_file "$tmp_repo" "website/index.html" "site" "Refresh marketing site"
commit_file "$tmp_repo" "k8s/deployment.yaml" "deployment" "Deploy website to Kubernetes"
commit_file "$tmp_repo" ".woodpecker/website.yaml" "pipeline" "Update website pipeline"
commit_file "$tmp_repo" "README.md" "docs" "Document hosting setup"
commit_file "$tmp_repo" "macos/ViceMac/ContentView.swift" "machine" "Fix C128 display restore"

git -C "$tmp_repo" checkout -q -b upstream vice-mac-0.1
commit_file "$tmp_repo" "src/sid/sid.c" "sid" "Fix upstream SID filter"
git -C "$tmp_repo" update-ref refs/remotes/upstream/main HEAD

git -C "$tmp_repo" checkout -q "$main_branch"
git -C "$tmp_repo" merge -q --no-ff upstream -m "Merge upstream VICE"
git -C "$tmp_repo" tag vice-mac-0.2

REPO_ROOT="$tmp_repo"
notes_file="$tmp_repo/release-notes.md"
VICE_MAC_RELEASE_NOTE_SCAN_LIMIT=100 write_release_notes vice-mac-0.2 "$notes_file"

assert_contains "$notes_file" "## VICE Mac 0.2"
assert_contains "$notes_file" "Fix C128 display restore"
assert_contains "$notes_file" "Fix upstream SID filter"
assert_contains "$notes_file" "_upstream VICE_"
assert_contains "$notes_file" "### Package"
assert_not_contains "$notes_file" "<div"
assert_not_contains "$notes_file" "<span"
assert_not_contains "$notes_file" "Refresh marketing site"
assert_not_contains "$notes_file" "Deploy website to Kubernetes"
assert_not_contains "$notes_file" "Update website pipeline"
assert_not_contains "$notes_file" "Document hosting setup"

appcast_notes_file="$tmp_repo/appcast-release-notes.html"
write_appcast_release_notes vice-mac-0.2 "$appcast_notes_file"

assert_contains "$appcast_notes_file" "<div"
assert_contains "$appcast_notes_file" "Fix C128 display restore"
assert_contains "$appcast_notes_file" "Fix upstream SID filter"
assert_contains "$appcast_notes_file" "Upstream VICE change"
assert_contains "$appcast_notes_file" "<span"
assert_not_contains "$appcast_notes_file" "Refresh marketing site"

commit_file "$tmp_repo" "website/index.html" "site-only" "Polish website gallery"
commit_file "$tmp_repo" "k8s/service.yaml" "service" "Update website service"
git -C "$tmp_repo" tag vice-mac-0.3

web_only_notes="$tmp_repo/web-only-release-notes.md"
write_release_notes vice-mac-0.3 "$web_only_notes"

assert_contains "$web_only_notes" "No emulator-facing changes"
assert_not_contains "$web_only_notes" "<li>"
assert_not_contains "$web_only_notes" "Polish website gallery"
assert_not_contains "$web_only_notes" "Update website service"

echo "release notes filtering test passed"

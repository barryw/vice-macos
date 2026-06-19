#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
    echo "coverage badge test failed: $*" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq "$expected" "$file"; then
        echo "Expected $file to contain: $expected" >&2
        echo "--- $file ---" >&2
        cat "$file" >&2
        fail "missing expected text"
    fi
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/vicemac-coverage-badge-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/report.json" <<'JSON'
{
  "lineCoverage": 0.8734,
  "targets": []
}
JSON

bash "$SCRIPT_DIR/write-coverage-badge.sh" \
    --json "$tmp_dir/report.json" \
    "$tmp_dir/coverage.json" \
    "$tmp_dir/coverage.txt"

assert_contains "$tmp_dir/coverage.json" '"schemaVersion": 1'
assert_contains "$tmp_dir/coverage.json" '"label": "coverage"'
assert_contains "$tmp_dir/coverage.json" '"message": "87.3%"'
assert_contains "$tmp_dir/coverage.json" '"color": "green"'
assert_contains "$tmp_dir/coverage.txt" 'Line coverage: 87.3%'

echo "coverage badge test passed"

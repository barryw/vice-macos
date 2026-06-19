#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage:
  write-coverage-badge.sh <result.xcresult> <coverage.json> [coverage.txt]
  write-coverage-badge.sh --json <xccov-report.json> <coverage.json> [coverage.txt]
EOF
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

coverage_percent_from_report_json() {
    local report_json="$1"
    local line_coverage

    line_coverage="$(plutil -extract lineCoverage raw -o - "$report_json" 2>/dev/null || true)"
    if [[ -z "$line_coverage" ]]; then
        echo "Coverage report is missing top-level lineCoverage." >&2
        return 1
    fi

    awk -v coverage="$line_coverage" 'BEGIN { printf "%.1f", coverage * 100 }'
}

coverage_color() {
    local percent="$1"

    awk -v percent="$percent" 'BEGIN {
        if (percent >= 90) {
            print "brightgreen"
        } else if (percent >= 80) {
            print "green"
        } else if (percent >= 70) {
            print "yellowgreen"
        } else if (percent >= 60) {
            print "yellow"
        } else if (percent >= 50) {
            print "orange"
        } else {
            print "red"
        }
    }'
}

write_badge_json() {
    local percent="$1"
    local output="$2"
    local color

    color="$(coverage_color "$percent")"
    mkdir -p "$(dirname "$output")"
    cat > "$output" <<EOF
{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "$percent%",
  "color": "$color"
}
EOF
}

write_summary() {
    local percent="$1"
    local summary="$2"

    mkdir -p "$(dirname "$summary")"
    {
        echo "VICE Mac test coverage"
        echo
        echo "Line coverage: $percent%"
    } > "$summary"
}

main() {
    local report_source=""
    local output=""
    local summary=""
    local temp_report=""

    if [[ "${1:-}" == "--json" ]]; then
        if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
            usage
            exit 64
        fi
        require_tool plutil "plutil ships with macOS."
        report_source="$2"
        output="$3"
        summary="${4:-}"
    else
        if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
            usage
            exit 64
        fi
        require_tool xcrun "xcrun ships with Xcode command line tools."
        require_tool plutil "plutil ships with macOS."
        temp_report="$(mktemp "${TMPDIR:-/tmp}/vicemac-xccov-report.XXXXXX.json")"
        xcrun xccov view --report --json "$1" > "$temp_report"
        report_source="$temp_report"
        output="$2"
        summary="${3:-}"
    fi

    if [[ ! -f "$report_source" ]]; then
        echo "Coverage report does not exist: $report_source" >&2
        exit 1
    fi

    local percent
    percent="$(coverage_percent_from_report_json "$report_source")"
    write_badge_json "$percent" "$output"

    if [[ -n "$summary" ]]; then
        write_summary "$percent" "$summary"
    fi

    if [[ -n "$temp_report" ]]; then
        rm -f "$temp_report"
    fi

    echo "Wrote coverage badge: $output ($percent%)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

#!/usr/bin/env bash
# Align two [TurboDiag] traces (passing kit run vs failing app run) at the
# last machine-reset and show the first divergence in event ORDER (clk
# values differ run-to-run; we diff the event stream, not timestamps).
# Usage: turbodiag-diff.sh good.log bad.log
set -euo pipefail

[[ $# -eq 2 ]] || { echo "usage: $0 good.log bad.log" >&2; exit 2; }

normalize() {
    # keep everything after the last machine-reset; drop clk stamps
    awk '/machine-reset/ { n = NR } { lines[NR] = $0 } END {
             if (n == 0) { n = 1 }
             for (i = n; i <= NR; i++) { print lines[i] }
         }' "$1" | sed -E 's/clk=[0-9]+ //'
}

diff -u <(normalize "$1") <(normalize "$2") | head -80

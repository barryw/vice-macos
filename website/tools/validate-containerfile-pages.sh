#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WEBSITE_DIR="$ROOT_DIR/website"
CONTAINERFILE="$WEBSITE_DIR/Containerfile"

missing=0
while IFS= read -r page; do
    page_name="$(basename "$page")"
    if ! grep -Eq "(^|[[:space:]])${page_name}([[:space:]]|$)" "$CONTAINERFILE"; then
        echo "Containerfile does not copy $page_name" >&2
        missing=1
    fi
done < <(find "$WEBSITE_DIR" -maxdepth 1 -type f -name '*.html' -print | sort)

if [[ -d "$WEBSITE_DIR/docs" ]] &&
   ! grep -Eq '(^|[[:space:]])docs([[:space:]]|$)' "$CONTAINERFILE"; then
    echo "Containerfile does not copy docs" >&2
    missing=1
fi

if [[ ! -f "$WEBSITE_DIR/docs/macvicekit/documentation/macvicekit/index.html" ]]; then
    echo "MacVICEKit DocC website docs are missing; run website/tools/build-macvicekit-docs.sh" >&2
    missing=1
fi

exit "$missing"

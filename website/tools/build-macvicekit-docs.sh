#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PACKAGE_DIR="$REPO_ROOT/MacVICEKit"
DERIVED_DATA="${MACVICEKIT_DOC_DERIVED_DATA:-/private/tmp/macvicekit-docbuild}"
OUTPUT_DIR="${MACVICEKIT_DOC_OUTPUT_DIR:-$REPO_ROOT/website/docs/macvicekit}"
HOSTING_BASE_PATH="${MACVICEKIT_DOC_HOSTING_BASE_PATH:-/docs/macvicekit}"

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

require_tool xcodebuild "Install Xcode."
require_tool xcrun "Install Xcode command line tools."
require_tool perl "perl ships with macOS."

rm -rf "$DERIVED_DATA"
(
    cd "$PACKAGE_DIR"
    xcodebuild docbuild \
        -scheme MacVICEKit \
        -destination generic/platform=macOS \
        -derivedDataPath "$DERIVED_DATA" \
        -quiet
)

archive="$(find "$DERIVED_DATA/Build/Products" -name 'MacVICEKit.doccarchive' -type d -print -quit)"
if [[ -z "$archive" ]]; then
    echo "MacVICEKit.doccarchive was not produced." >&2
    exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$(dirname "$OUTPUT_DIR")"
xcrun docc process-archive transform-for-static-hosting \
    "$archive" \
    --output-path "$OUTPUT_DIR" \
    --hosting-base-path "$HOSTING_BASE_PATH"

cat > "$OUTPUT_DIR/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/macvicekit/">
    <title>MacVICEKit Documentation</title>
    <script>
      window.location.replace("documentation/macvicekit/" + window.location.search + window.location.hash);
    </script>
  </head>
  <body>
    <p><a href="documentation/macvicekit/">MacVICEKit Documentation</a></p>
  </body>
</html>
EOF

while IFS= read -r -d '' text_file; do
    perl -0pi -e 's/[ \t]+(\r?\n)/$1/g' "$text_file"
done < <(find "$OUTPUT_DIR" -type f \( \
    -name '*.css' -o \
    -name '*.html' -o \
    -name '*.js' -o \
    -name '*.json' -o \
    -name '*.svg' \
\) -print0)

while IFS= read -r -d '' json_file; do
    perl -MJSON::PP -0pi -e '
        my $json = JSON::PP->new->utf8->decode($_);
        $_ = JSON::PP->new->canonical->utf8->encode($json);
    ' "$json_file"
done < <(find "$OUTPUT_DIR" -type f -name '*.json' -print0)

echo "Generated $OUTPUT_DIR"

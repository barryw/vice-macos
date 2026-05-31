#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$MACOS_DIR/ViceMac.xcodeproj"
DERIVED_DATA="${VICE_MAC_CI_DERIVED_DATA:-/private/tmp/vice-macos-ci-derived-data}"
CONFIGURATION="${VICE_MAC_CI_CONFIGURATION:-Debug}"
DESTINATION="${VICE_MAC_CI_DESTINATION:-platform=macOS,arch=arm64}"

swift test --package-path "$MACOS_DIR/../MacVICEKit"
bash -n "$SCRIPT_DIR/package-macvicekit-runtime.sh"

SCHEMES=(
    "VICE Mac C64"
    "VICE Mac VIC-20"
    "VICE Mac PET"
    "VICE Mac Plus-4"
    "VICE Mac C16"
    "VICE Mac C232"
    "VICE Mac V364"
    "VICE Mac C128"
    "VICE Mac VSID"
)

for scheme in "${SCHEMES[@]}"; do
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build
done

xcodebuild \
    test \
    -project "$PROJECT" \
    -scheme "VICE Mac Tests" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA"

bash "$SCRIPT_DIR/test-release-notes.sh"

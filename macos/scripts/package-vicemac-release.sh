#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
PROJECT="$MACOS_DIR/ViceMac.xcodeproj"
DERIVED_DATA="${VICE_MAC_RELEASE_DERIVED_DATA:-/private/tmp/vice-macos-release-derived-data}"
DIST_DIR="${VICE_MAC_DIST_DIR:-$MACOS_DIR/dist}"
CONFIGURATION="${VICE_MAC_RELEASE_CONFIGURATION:-Release}"
DESTINATION="${VICE_MAC_RELEASE_DESTINATION:-platform=macOS,arch=arm64}"

SCHEMES=(
    "VICE Mac C64"
    "VICE Mac VIC-20"
    "VICE Mac PET"
    "VICE Mac Plus-4"
    "VICE Mac C16"
    "VICE Mac C232"
    "VICE Mac V364"
    "VICE Mac C128"
)

vice_version() {
    local configure_ac="$REPO_ROOT/vice/configure.ac"
    local major
    local minor
    local build

    major="$(sed -n 's/^m4_define(vice_version_major, \([0-9][0-9]*\))/\1/p' "$configure_ac")"
    minor="$(sed -n 's/^m4_define(vice_version_minor, \([0-9][0-9]*\))/\1/p' "$configure_ac")"
    build="$(sed -n 's/^m4_define(vice_version_build, \([0-9][0-9]*\))/\1/p' "$configure_ac")"

    if [[ -z "$major" || -z "$minor" || -z "$build" ]]; then
        echo "unknown"
    elif [[ "$build" == "0" ]]; then
        echo "$major.$minor"
    else
        echo "$major.$minor.$build"
    fi
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

copy_release_apps() {
    local products_dir="$1"
    local stage_dir="$2"
    local copied=0

    mkdir -p "$stage_dir"

    while IFS= read -r app; do
        ditto "$app" "$stage_dir/$(basename "$app")"
        copied=$((copied + 1))
    done < <(find "$products_dir" -maxdepth 1 -type d -name "VICE Mac*.app" | sort)

    if [[ "$copied" -eq 0 ]]; then
        echo "No VICE Mac apps were found in $products_dir." >&2
        exit 1
    fi
}

create_dmg() {
    local source_dir="$1"
    local volume_name="$2"
    local dmg_path="$3"
    local temp_dmg="${dmg_path%.dmg}.tmp.dmg"

    rm -f "$temp_dmg" "$dmg_path"

    hdiutil create \
        -volname "$volume_name" \
        -srcfolder "$source_dir" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        "$temp_dmg"

    hdiutil convert "$temp_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "$dmg_path"

    rm -f "$temp_dmg"
}

require_tool xcodebuild "Install the latest Xcode and select it with xcode-select."
require_tool hdiutil "hdiutil ships with macOS."
require_tool ditto "ditto ships with macOS."
require_tool shasum "shasum ships with macOS."

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

for scheme in "${SCHEMES[@]}"; do
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build
done

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"
VICE_VERSION="$(vice_version)"
VOLUME_NAME="VICE Mac $VICE_VERSION"
STAGE_ROOT="$DIST_DIR/stage"
STAGE_DIR="$STAGE_ROOT/$VOLUME_NAME"
DMG_PATH="$DIST_DIR/VICE-Mac-$VICE_VERSION-arm64.dmg"

rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_DIR"

copy_release_apps "$PRODUCTS_DIR" "$STAGE_DIR"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/README.txt" <<EOF
VICE Mac $VICE_VERSION

Drag the VICE Mac apps you want to use into Applications.

These apps are built for Apple Silicon Macs and use the upstream VICE engine.
EOF

create_dmg "$STAGE_DIR" "$VOLUME_NAME" "$DMG_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" > SHA256SUMS.txt
)

rm -rf "$STAGE_ROOT"

echo "Created $DMG_PATH"

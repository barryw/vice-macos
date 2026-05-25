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
CODE_SIGN_IDENTITY="${VICE_MAC_CODESIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${VICE_MAC_DEVELOPMENT_TEAM:-}"
NOTARIZE_MODE="${VICE_MAC_NOTARIZE:-auto}"
NOTARYTOOL_PROFILE="${VICE_MAC_NOTARYTOOL_PROFILE:-}"
NOTARYTOOL_APPLE_ID="${VICE_MAC_NOTARYTOOL_APPLE_ID:-}"
NOTARYTOOL_PASSWORD="${VICE_MAC_NOTARYTOOL_PASSWORD:-}"
NOTARYTOOL_TEAM_ID="${VICE_MAC_NOTARYTOOL_TEAM_ID:-$DEVELOPMENT_TEAM}"

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

RELEASE_APPS=(
    x64sc
    xvic
    xpet
    xplus4
    xc16
    xc232
    xv364
    x128
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

release_asset_version() {
    if [[ -n "${VICE_MAC_RELEASE_VERSION:-}" ]]; then
        echo "${VICE_MAC_RELEASE_VERSION#vice-mac-}"
    elif [[ -n "${CI_COMMIT_TAG:-}" ]]; then
        echo "${CI_COMMIT_TAG#vice-mac-}"
    elif [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        "$SCRIPT_DIR/compute-vicemac-version.sh" | sed 's/^vice-mac-//'
    else
        vice_version
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

notarization_enabled() {
    case "$NOTARIZE_MODE" in
        1|true|TRUE|yes|YES|on|ON)
            return 0
            ;;
        0|false|FALSE|no|NO|off|OFF)
            return 1
            ;;
        auto|"")
            [[ -n "$NOTARYTOOL_PROFILE" || -n "$NOTARYTOOL_APPLE_ID$NOTARYTOOL_PASSWORD" ]]
            ;;
        *)
            echo "Invalid VICE_MAC_NOTARIZE value: $NOTARIZE_MODE" >&2
            echo "Use 1, 0, or leave it unset for auto." >&2
            exit 1
            ;;
    esac
}

codesigning_enabled() {
    [[ -n "$CODE_SIGN_IDENTITY" && "$CODE_SIGN_IDENTITY" != "-" ]]
}

configure_notarytool_args() {
    NOTARYTOOL_ARGS=()

    if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
        NOTARYTOOL_ARGS=(--keychain-profile "$NOTARYTOOL_PROFILE")
        return
    fi

    if [[ -n "$NOTARYTOOL_APPLE_ID" && -n "$NOTARYTOOL_PASSWORD" && -n "$NOTARYTOOL_TEAM_ID" ]]; then
        NOTARYTOOL_ARGS=(
            --apple-id "$NOTARYTOOL_APPLE_ID"
            --password "$NOTARYTOOL_PASSWORD"
            --team-id "$NOTARYTOOL_TEAM_ID"
        )
        return
    fi

    echo "Notarization is enabled, but notarytool credentials are incomplete." >&2
    echo "Set VICE_MAC_NOTARYTOOL_PROFILE or set VICE_MAC_NOTARYTOOL_APPLE_ID, VICE_MAC_NOTARYTOOL_PASSWORD, and VICE_MAC_NOTARYTOOL_TEAM_ID." >&2
    exit 1
}

configure_xcodebuild_settings() {
    XCODEBUILD_SETTINGS=()

    if [[ -n "$CODE_SIGN_IDENTITY" ]]; then
        XCODEBUILD_SETTINGS+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")

        if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
            XCODEBUILD_SETTINGS+=("OTHER_CODE_SIGN_FLAGS=--timestamp")
            XCODEBUILD_SETTINGS+=("CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO")
        fi
    fi

    if [[ -n "$DEVELOPMENT_TEAM" ]]; then
        XCODEBUILD_SETTINGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    fi
}

copy_release_apps() {
    local products_dir="$1"
    local stage_dir="$2"
    local copied=0
    local app_name
    local app

    mkdir -p "$stage_dir"

    for app_name in "${RELEASE_APPS[@]}"; do
        app="$products_dir/$app_name.app"
        if [[ ! -d "$app" ]]; then
            echo "Expected release app is missing: $app" >&2
            exit 1
        fi

        ditto "$app" "$stage_dir/$(basename "$app")"
        copied=$((copied + 1))
    done

    if [[ "$copied" -eq 0 ]]; then
        echo "No release apps were found in $products_dir." >&2
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

verify_release_apps() {
    local stage_dir="$1"
    local app_name
    local app

    for app_name in "${RELEASE_APPS[@]}"; do
        app="$stage_dir/$app_name.app"
        codesign --verify --deep --strict --verbose=2 "$app"
    done
}

sign_dmg() {
    local dmg_path="$1"

    if ! codesigning_enabled; then
        return
    fi

    codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$dmg_path"
    codesign --verify --verbose=2 "$dmg_path"
}

notarize_and_staple_dmg() {
    local dmg_path="$1"

    xcrun notarytool submit "$dmg_path" "${NOTARYTOOL_ARGS[@]}" --wait
    xcrun stapler staple "$dmg_path"
    xcrun stapler validate "$dmg_path"
}

require_tool xcodebuild "Install the latest Xcode and select it with xcode-select."
require_tool hdiutil "hdiutil ships with macOS."
require_tool ditto "ditto ships with macOS."
require_tool shasum "shasum ships with macOS."

NOTARIZE=0
if notarization_enabled; then
    NOTARIZE=1
fi

if [[ "$NOTARIZE" -eq 1 ]]; then
    if ! codesigning_enabled; then
        echo "Notarization requires VICE_MAC_CODESIGN_IDENTITY to be a Developer ID Application identity." >&2
        exit 1
    fi

    require_tool xcrun "xcrun ships with Xcode command line tools."
    require_tool codesign "codesign ships with macOS."
    configure_notarytool_args
elif codesigning_enabled; then
    require_tool codesign "codesign ships with macOS."
fi

configure_xcodebuild_settings

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

for scheme in "${SCHEMES[@]}"; do
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        "${XCODEBUILD_SETTINGS[@]}" \
        build
done

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"
VICE_VERSION="$(vice_version)"
RELEASE_ASSET_VERSION="$(release_asset_version)"
VOLUME_NAME="VICE Mac $VICE_VERSION"
STAGE_ROOT="$DIST_DIR/stage"
STAGE_DIR="$STAGE_ROOT/$VOLUME_NAME"
DMG_PATH="$DIST_DIR/VICE-Mac-$RELEASE_ASSET_VERSION-arm64.dmg"

rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_DIR"

copy_release_apps "$PRODUCTS_DIR" "$STAGE_DIR"
ln -s /Applications "$STAGE_DIR/Applications"

if codesigning_enabled; then
    verify_release_apps "$STAGE_DIR"
fi

cat > "$STAGE_DIR/README.txt" <<EOF
VICE Mac $VICE_VERSION

Drag the machine apps you want to use into Applications.

These apps are built for Apple Silicon Macs and use the upstream VICE engine.
EOF

create_dmg "$STAGE_DIR" "$VOLUME_NAME" "$DMG_PATH"
sign_dmg "$DMG_PATH"

if [[ "$NOTARIZE" -eq 1 ]]; then
    notarize_and_staple_dmg "$DMG_PATH"
fi

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" > SHA256SUMS.txt
)

rm -rf "$STAGE_ROOT"

echo "Created $DMG_PATH"

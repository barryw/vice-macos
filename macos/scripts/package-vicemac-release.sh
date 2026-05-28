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
XCODE_TOOLCHAIN="${VICE_MAC_XCODE_TOOLCHAIN:-}"
CODE_SIGN_IDENTITY="${VICE_MAC_CODESIGN_IDENTITY:-}"
CODE_SIGN_KEYCHAIN="${VICE_MAC_CODESIGN_KEYCHAIN:-}"
DEVELOPMENT_TEAM="${VICE_MAC_DEVELOPMENT_TEAM:-}"
NOTARIZE_MODE="${VICE_MAC_NOTARIZE:-auto}"
NOTARYTOOL_PROFILE="${VICE_MAC_NOTARYTOOL_PROFILE:-}"
NOTARYTOOL_KEYCHAIN="${VICE_MAC_NOTARYTOOL_KEYCHAIN:-}"
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
    "VICE Mac VSID"
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
    vsid
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

release_bundle_version() {
    if [[ -n "${VICE_MAC_BUILD_VERSION:-}" ]]; then
        echo "$VICE_MAC_BUILD_VERSION"
        return
    fi

    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        git -C "$REPO_ROOT" show -s --format=%ct "$CI_COMMIT_SHA"
        return
    fi

    if git -C "$REPO_ROOT" rev-parse --verify HEAD >/dev/null 2>&1; then
        git -C "$REPO_ROOT" show -s --format=%ct HEAD
        return
    fi

    date +%s
}

short_git_sha_value() {
    local value="$1"
    local short_value

    short_value="$(git -C "$REPO_ROOT" rev-parse --short=12 "$value" 2>/dev/null || true)"
    if [[ -n "$short_value" ]]; then
        echo "$short_value"
        return
    fi

    printf '%s\n' "${value:0:12}"
}

release_mac_git_sha() {
    local sha

    if [[ -n "${VICE_MAC_GIT_SHA:-}" ]]; then
        echo "$VICE_MAC_GIT_SHA"
        return
    fi

    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        short_git_sha_value "$CI_COMMIT_SHA"
        return
    fi

    sha="$(short_git_sha_value HEAD)"
    if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
        sha="${sha}-dirty"
    fi

    echo "$sha"
}

release_upstream_git_sha() {
    local merge_base
    local parents
    local upstream_ref

    if [[ -n "${VICE_UPSTREAM_GIT_SHA:-}" ]]; then
        echo "$VICE_UPSTREAM_GIT_SHA"
        return
    fi

    for upstream_ref in refs/remotes/upstream/main upstream/main FETCH_HEAD; do
        if ! git -C "$REPO_ROOT" rev-parse --verify "$upstream_ref^{commit}" >/dev/null 2>&1; then
            continue
        fi

        merge_base="$(git -C "$REPO_ROOT" merge-base HEAD "$upstream_ref" 2>/dev/null || true)"
        if [[ -n "$merge_base" ]]; then
            short_git_sha_value "$merge_base"
            return
        fi
    done

    parents="$(git -C "$REPO_ROOT" log --merges --first-parent --format=%P -n 1 HEAD 2>/dev/null || true)"
    set -- $parents
    if [[ $# -ge 2 ]]; then
        short_git_sha_value "$2"
        return
    fi

    echo "unknown"
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

trim_keychain_path() {
    local keychain="$1"

    keychain="${keychain//\"/}"
    keychain="${keychain#"${keychain%%[![:space:]]*}"}"
    keychain="${keychain%"${keychain##*[![:space:]]}"}"
    keychain="${keychain/#\~\//$HOME/}"

    echo "$keychain"
}

append_existing_keychain() {
    local keychain="$1"
    local existing_keychain

    keychain="$(trim_keychain_path "$keychain")"
    if [[ -z "$keychain" || ! -f "$keychain" ]]; then
        return
    fi

    if [[ "${KEYCHAIN_SEARCH_LIST_COUNT:-0}" -gt 0 ]]; then
        for existing_keychain in "${KEYCHAIN_SEARCH_LIST[@]}"; do
            if [[ "$existing_keychain" == "$keychain" ]]; then
                return
            fi
        done
    fi

    KEYCHAIN_SEARCH_LIST[$KEYCHAIN_SEARCH_LIST_COUNT]="$keychain"
    KEYCHAIN_SEARCH_LIST_COUNT=$((KEYCHAIN_SEARCH_LIST_COUNT + 1))
}

current_user_home() {
    local user_name
    local user_home

    user_name="$(id -un 2>/dev/null || true)"
    if [[ -n "$user_name" ]]; then
        user_home="$(dscl . -read "/Users/$user_name" NFSHomeDirectory 2>/dev/null | sed -n 's/^NFSHomeDirectory: //p' | head -n 1)"
        if [[ -n "$user_home" ]]; then
            echo "$user_home"
            return
        fi
    fi

    if [[ -n "$user_name" && -d "/Users/$user_name" ]]; then
        echo "/Users/$user_name"
        return
    fi

    echo "$HOME"
}

configure_user_home() {
    local user_home

    user_home="$(current_user_home)"
    if [[ -n "$user_home" && -d "$user_home" ]]; then
        export HOME="$user_home"
    fi
}

collect_codesign_keychains() {
    local default_keychain
    local existing_keychain
    local login_keychain
    local user_home

    if ! codesigning_enabled; then
        return
    fi

    KEYCHAIN_SEARCH_LIST=()
    KEYCHAIN_SEARCH_LIST_COUNT=0

    if [[ -n "$CODE_SIGN_KEYCHAIN" ]]; then
        append_existing_keychain "$CODE_SIGN_KEYCHAIN"
    fi

    if [[ -n "${VICE_MAC_CODESIGN_LOGIN_KEYCHAIN:-}" ]]; then
        append_existing_keychain "$VICE_MAC_CODESIGN_LOGIN_KEYCHAIN"
    fi

    login_keychain="$(security login-keychain -d user 2>/dev/null || true)"
    append_existing_keychain "$login_keychain"

    default_keychain="$(security default-keychain -d user 2>/dev/null || true)"
    append_existing_keychain "$default_keychain"

    append_existing_keychain "$HOME/Library/Keychains/login.keychain-db"

    user_home="$(current_user_home)"
    append_existing_keychain "$user_home/Library/Keychains/login.keychain-db"

    while IFS= read -r existing_keychain; do
        append_existing_keychain "$existing_keychain"
    done < <(security list-keychains -d user 2>/dev/null || true)

    if [[ "$KEYCHAIN_SEARCH_LIST_COUNT" -eq 0 ]]; then
        echo "No user keychains were found for codesigning." >&2
    fi
}

codesign_identity_visible() {
    local identities="$1"

    printf '%s\n' "$identities" | grep -Fq "$CODE_SIGN_IDENTITY"
}

configure_codesign_default_keychain() {
    local identities
    local keychain
    local keychain_identities

    if ! codesigning_enabled; then
        return
    fi

    identities="$(security find-identity -v -p codesigning 2>&1 || true)"
    if codesign_identity_visible "$identities"; then
        return
    fi

    if [[ "${KEYCHAIN_SEARCH_LIST_COUNT:-0}" -eq 0 ]]; then
        return
    fi

    for keychain in "${KEYCHAIN_SEARCH_LIST[@]}"; do
        keychain_identities="$(security find-identity -v -p codesigning "$keychain" 2>&1 || true)"
        if codesign_identity_visible "$keychain_identities"; then
            security list-keychains -d user -s "${KEYCHAIN_SEARCH_LIST[@]}"
            security default-keychain -d user -s "$keychain"
            return
        fi
    done
}

verify_codesign_identity_available() {
    local identities
    local keychain
    local keychain_identities
    local keychain_identity_reports=""

    if ! codesigning_enabled; then
        return
    fi

    identities="$(security find-identity -v -p codesigning 2>&1 || true)"

    if codesign_identity_visible "$identities"; then
        return
    fi

    if [[ "${KEYCHAIN_SEARCH_LIST_COUNT:-0}" -gt 0 ]]; then
        for keychain in "${KEYCHAIN_SEARCH_LIST[@]}"; do
            keychain_identities="$(security find-identity -v -p codesigning "$keychain" 2>&1 || true)"
            keychain_identity_reports+=$'\n'"$keychain:"$'\n'"$keychain_identities"$'\n'
        done
    fi

    echo "Configured codesign identity is not visible to this process." >&2
    echo "User keychain search list:" >&2
    security list-keychains -d user >&2 || true
    echo "Visible codesigning identities:" >&2
    printf '%s\n' "$identities" >&2
    if [[ -n "$keychain_identity_reports" ]]; then
        echo "Codesigning identities by keychain:" >&2
        printf '%s' "$keychain_identity_reports" >&2
    fi
    exit 1
}

configure_notarytool_args() {
    NOTARYTOOL_ARGS=()

    if [[ -n "$NOTARYTOOL_PROFILE" ]]; then
        NOTARYTOOL_ARGS=(--keychain-profile "$NOTARYTOOL_PROFILE")
        local notarytool_keychain

        notarytool_keychain="$(resolve_notarytool_keychain)"
        if [[ -n "$notarytool_keychain" ]]; then
            NOTARYTOOL_ARGS+=(--keychain "$notarytool_keychain")
        fi
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

resolve_notarytool_keychain() {
    local keychain

    if [[ -n "$NOTARYTOOL_KEYCHAIN" ]]; then
        keychain="$(trim_keychain_path "$NOTARYTOOL_KEYCHAIN")"
        if [[ ! -f "$keychain" ]]; then
            echo "Configured notarytool keychain does not exist: $keychain" >&2
            exit 1
        fi
        echo "$keychain"
        return
    fi

    keychain="$(security login-keychain -d user 2>/dev/null || true)"
    keychain="$(trim_keychain_path "$keychain")"
    if [[ -f "$keychain" ]]; then
        echo "$keychain"
        return
    fi

    keychain="$HOME/Library/Keychains/login.keychain-db"
    if [[ -f "$keychain" ]]; then
        echo "$keychain"
    fi
}

configure_xcodebuild_settings() {
    XCODEBUILD_SETTINGS=()

    XCODEBUILD_SETTINGS+=("MARKETING_VERSION=$DISPLAY_VERSION")
    XCODEBUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=$BUNDLE_VERSION")
    XCODEBUILD_SETTINGS+=("VICE_MAC_GIT_SHA=$MAC_GIT_SHA")
    XCODEBUILD_SETTINGS+=("VICE_UPSTREAM_GIT_SHA=$UPSTREAM_GIT_SHA")

    # Final artifacts are signed after staging. Passing a manual identity here
    # breaks automatically signed Swift package bundles such as Waveform.
    if [[ -n "$DEVELOPMENT_TEAM" ]]; then
        XCODEBUILD_SETTINGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
    fi
}

detect_metal_toolchain() {
    local component_info
    local status
    local identifier

    component_info="$(xcodebuild -showComponent MetalToolchain 2>/dev/null || true)"
    status="$(printf '%s\n' "$component_info" | sed -n 's/^Status: //p' | head -n 1)"
    identifier="$(printf '%s\n' "$component_info" | sed -n 's/^Toolchain Identifier: //p' | head -n 1)"

    if [[ "$status" == "installed" && -n "$identifier" ]]; then
        echo "$identifier"
    fi
}

configure_xcodebuild_args() {
    XCODEBUILD_ARGS=()

    if [[ -z "$XCODE_TOOLCHAIN" && "${VICE_MAC_AUTO_METAL_TOOLCHAIN:-1}" != "0" ]]; then
        XCODE_TOOLCHAIN="$(detect_metal_toolchain)"
    fi

    if [[ -n "$XCODE_TOOLCHAIN" ]]; then
        XCODEBUILD_ARGS+=("-toolchain" "$XCODE_TOOLCHAIN")
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
        verify_release_app_dependencies "$app"
    done
}

is_disallowed_runtime_dependency() {
    local dependency="$1"

    case "$dependency" in
        /opt/homebrew/*|/usr/local/*|/opt/local/*)
            return 0
            ;;
    esac

    return 1
}

verify_binary_dependencies() {
    local binary="$1"
    local dependency

    while IFS= read -r dependency; do
        if [[ -n "$dependency" ]] && is_disallowed_runtime_dependency "$dependency"; then
            echo "Release binary has an unbundled local dependency: $binary -> $dependency" >&2
            exit 1
        fi
    done < <(otool -L "$binary" | sed '1d; s/^[[:space:]]*//; s/[[:space:]]*(.*//')
}

verify_release_app_dependencies() {
    local app="$1"
    local binary

    for binary in "$app/Contents/MacOS"/* "$app/Contents/Frameworks"/*.dylib; do
        if [[ -f "$binary" ]]; then
            verify_binary_dependencies "$binary"
        fi
    done
}

codesign_release_path() {
    local path="$1"
    shift
    local codesign_args

    codesign_args=(--force)
    if [[ -n "$CODE_SIGN_KEYCHAIN" ]]; then
        codesign_args+=(--keychain "$CODE_SIGN_KEYCHAIN")
    fi
    codesign_args+=(--sign "$CODE_SIGN_IDENTITY" --options runtime --timestamp)
    codesign_args+=("$@")
    codesign_args+=("$path")

    codesign "${codesign_args[@]}"
}

resign_sparkle_framework() {
    local app="$1"
    local sparkle_framework="$app/Contents/Frameworks/Sparkle.framework"
    local sparkle_version="$sparkle_framework/Versions/B"
    local component

    if [[ ! -d "$sparkle_framework" ]]; then
        return
    fi

    if [[ ! -d "$sparkle_version" ]]; then
        sparkle_version="$sparkle_framework/Versions/Current"
    fi

    if [[ ! -d "$sparkle_version" ]]; then
        echo "Sparkle.framework has an unexpected layout in $app." >&2
        exit 1
    fi

    echo "Re-signing Sparkle helpers in $(basename "$app")"

    for component in \
        "$sparkle_version/Autoupdate" \
        "$sparkle_version/Updater.app" \
        "$sparkle_version"/XPCServices/*.xpc
    do
        if [[ -e "$component" ]]; then
            codesign_release_path "$component" --preserve-metadata=identifier,entitlements,flags
        fi
    done

    codesign_release_path "$sparkle_framework" --preserve-metadata=identifier,entitlements,flags
}

resign_embedded_dylibs() {
    local app="$1"
    local framework_dir="$app/Contents/Frameworks"
    local dylib

    if [[ ! -d "$framework_dir" ]]; then
        return
    fi

    for dylib in "$framework_dir"/*.dylib; do
        if [[ -f "$dylib" ]]; then
            codesign_release_path "$dylib" --preserve-metadata=identifier,flags
        fi
    done
}

resign_release_apps() {
    local stage_dir="$1"
    local app_name
    local app

    for app_name in "${RELEASE_APPS[@]}"; do
        app="$stage_dir/$app_name.app"
        resign_embedded_dylibs "$app"
        resign_sparkle_framework "$app"
        codesign_release_path "$app"
    done
}

sign_dmg() {
    local dmg_path="$1"
    local codesign_args

    if ! codesigning_enabled; then
        return
    fi

    codesign_args=(--force)
    if [[ -n "$CODE_SIGN_KEYCHAIN" ]]; then
        codesign_args+=(--keychain "$CODE_SIGN_KEYCHAIN")
    fi
    codesign_args+=(--sign "$CODE_SIGN_IDENTITY" --timestamp "$dmg_path")

    codesign "${codesign_args[@]}"
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
require_tool otool "otool ships with Xcode command line tools."

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

configure_user_home
collect_codesign_keychains
configure_codesign_default_keychain
verify_codesign_identity_available
VICE_VERSION="$(vice_version)"
RELEASE_ASSET_VERSION="$(release_asset_version)"
DISPLAY_VERSION="${VICE_MAC_DISPLAY_VERSION:-$RELEASE_ASSET_VERSION}"
BUNDLE_VERSION="$(release_bundle_version)"
MAC_GIT_SHA="$(release_mac_git_sha)"
UPSTREAM_GIT_SHA="$(release_upstream_git_sha)"
configure_xcodebuild_settings
configure_xcodebuild_args

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

for scheme in "${SCHEMES[@]}"; do
    xcodebuild \
        "${XCODEBUILD_ARGS[@]}" \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        "${XCODEBUILD_SETTINGS[@]}" \
        build
done

PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"
VOLUME_NAME="VICE Mac $VICE_VERSION"
STAGE_ROOT="$DIST_DIR/stage"
STAGE_DIR="$STAGE_ROOT/$VOLUME_NAME"
DMG_PATH="$DIST_DIR/VICE-Mac-$RELEASE_ASSET_VERSION-arm64.dmg"

rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE_DIR"

copy_release_apps "$PRODUCTS_DIR" "$STAGE_DIR"
ln -s /Applications "$STAGE_DIR/Applications"

if codesigning_enabled; then
    resign_release_apps "$STAGE_DIR"
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

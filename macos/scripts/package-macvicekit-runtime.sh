#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
VICE_SRC="$REPO_ROOT/vice"

DIST_DIR="${VICE_MAC_DIST_DIR:-$MACOS_DIR/dist}"
PRODUCTS_DIR="${VICE_MAC_RUNTIME_PRODUCTS_DIR:-$MACOS_DIR/BuildProducts}"
VERSION="${VICE_MAC_RUNTIME_VERSION:-$("$SCRIPT_DIR/compute-vicemac-version.sh" | sed 's/^vice-mac-//')}"
MINIMUM_MACOS_VERSION="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
FRAMEWORK_NAME="MacVICERuntime.framework"
FRAMEWORK_EXECUTABLE="MacVICERuntime"
FRAMEWORK_IDENTIFIER="com.barrywalker.MacVICERuntime"
MANIFEST_NAME="MacVICERuntimeManifest.json"
MACHINE_TARGETS="${VICE_MACOS_MACHINE_TARGETS:-x64sc x128 xvic xpet xplus4 vsid}"
SKIP_BUILD="${VICE_MAC_RUNTIME_SKIP_BUILD:-0}"
WORK_DIR="${VICE_MAC_RUNTIME_WORK_DIR:-$DIST_DIR/runtime-stage}"
SDK_NAME="MacVICEKit-$VERSION-arm64"
SDK_DIR="$WORK_DIR/$SDK_NAME"
FRAMEWORK_DIR="$WORK_DIR/$FRAMEWORK_NAME"
XCFRAMEWORK_NAME="MacVICERuntime.xcframework"
XCFRAMEWORK_DIR="$SDK_DIR/Runtime/$XCFRAMEWORK_NAME"
DOC_DERIVED_DATA="$WORK_DIR/macvicekit-docbuild"
SDK_ZIP_PATH="$DIST_DIR/$SDK_NAME.zip"
LATEST_SDK_ZIP_PATH="$DIST_DIR/MacVICEKit-latest-arm64.zip"

export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$PATH"

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

codesign_identity() {
    if [[ -n "${VICE_MAC_CODESIGN_IDENTITY:-}" ]]; then
        echo "$VICE_MAC_CODESIGN_IDENTITY"
    elif [[ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]]; then
        echo "$EXPANDED_CODE_SIGN_IDENTITY"
    else
        echo "-"
    fi
}

codesign_path() {
    local path="$1"
    local identity
    local codesign_args

    identity="$(codesign_identity)"
    codesign_args=(--force)
    if [[ -n "${VICE_MAC_CODESIGN_KEYCHAIN:-}" ]]; then
        codesign_args+=(--keychain "$VICE_MAC_CODESIGN_KEYCHAIN")
    fi

    if [[ "$identity" == "-" ]]; then
        codesign_args+=(--sign - --timestamp=none "$path")
    else
        codesign_args+=(--sign "$identity" --options runtime --timestamp "$path")
    fi

    codesign "${codesign_args[@]}"
}

short_git_sha() {
    local ref="$1"

    git -C "$REPO_ROOT" rev-parse --short=12 "$ref" 2>/dev/null || echo "unknown"
}

upstream_git_sha() {
    local merge_base
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
            short_git_sha "$merge_base"
            return
        fi
    done

    echo "unknown"
}

create_framework_skeleton() {
    local version_dir="$FRAMEWORK_DIR/Versions/A"
    local headers_dir="$version_dir/Headers"
    local modules_dir="$version_dir/Modules"
    local resources_dir="$version_dir/Resources"
    local frameworks_dir="$version_dir/Frameworks"
    local stub_source="$WORK_DIR/MacVICERuntime.c"

    rm -rf "$WORK_DIR" "$SDK_ZIP_PATH" "$LATEST_SDK_ZIP_PATH"
    mkdir -p "$headers_dir" "$modules_dir" "$resources_dir" "$frameworks_dir"

    ln -s A "$FRAMEWORK_DIR/Versions/Current"
    ln -s Versions/Current/$FRAMEWORK_EXECUTABLE "$FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"
    ln -s Versions/Current/Headers "$FRAMEWORK_DIR/Headers"
    ln -s Versions/Current/Modules "$FRAMEWORK_DIR/Modules"
    ln -s Versions/Current/Resources "$FRAMEWORK_DIR/Resources"
    ln -s Versions/Current/Frameworks "$FRAMEWORK_DIR/Frameworks"

    cat > "$resources_dir/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$FRAMEWORK_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>MinimumOSVersion</key>
    <string>$MINIMUM_MACOS_VERSION</string>
</dict>
</plist>
EOF

    cat > "$headers_dir/MacVICERuntime.h" <<EOF
#pragma once

int MacVICERuntimeArtifactVersion(void);
EOF

    cat > "$modules_dir/module.modulemap" <<EOF
framework module MacVICERuntime {
    umbrella header "MacVICERuntime.h"
    export *
    module * { export * }
}
EOF

    cat > "$stub_source" <<EOF
int MacVICERuntimeArtifactVersion(void)
{
    return 1;
}
EOF

    clang \
        -dynamiclib \
        -arch arm64 \
        -mmacosx-version-min="$MINIMUM_MACOS_VERSION" \
        -install_name "@rpath/$FRAMEWORK_NAME/$FRAMEWORK_EXECUTABLE" \
        -current_version 1 \
        -compatibility_version 1 \
        "$stub_source" \
        -o "$version_dir/$FRAMEWORK_EXECUTABLE"
}

copy_runtime_payload() {
    local frameworks_dir="$FRAMEWORK_DIR/Frameworks"
    local resources_dir="$FRAMEWORK_DIR/Resources"
    local target
    local dylib_name
    local dylib_path

    for target in $MACHINE_TARGETS; do
        dylib_name="libvicemac${target}.dylib"
        dylib_path="$PRODUCTS_DIR/$dylib_name"
        if [[ ! -f "$dylib_path" ]]; then
            echo "Missing runtime library: $dylib_path" >&2
            exit 1
        fi
    done

    for dylib_path in "$PRODUCTS_DIR"/*.dylib; do
        if [[ -f "$dylib_path" ]]; then
            cp "$dylib_path" "$frameworks_dir/$(basename "$dylib_path")"
        fi
    done

    rsync -a --delete "$VICE_SRC/data/" "$resources_dir/VICEData/"
}

copy_sdk_payload() {
    local docs_dir="$SDK_DIR/Documentation"

    mkdir -p "$SDK_DIR/Sources" "$SDK_DIR/Tests" "$SDK_DIR/Runtime" "$docs_dir"

    cat > "$SDK_DIR/Package.swift" <<EOF
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacVICEKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MacVICEKit",
            targets: ["MacVICEKit"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MacVICERuntime",
            path: "Runtime/$XCFRAMEWORK_NAME"
        ),
        .target(
            name: "CMacVICEEngineBridge"
        ),
        .target(
            name: "MacVICEKit",
            dependencies: [
                "CMacVICEEngineBridge",
                "MacVICERuntime"
            ]
        ),
        .testTarget(
            name: "MacVICEKitTests",
            dependencies: ["MacVICEKit"]
        )
    ]
)
EOF

    rsync -a --delete \
        --exclude ".build" \
        --exclude ".swiftpm" \
        --exclude ".DS_Store" \
        "$REPO_ROOT/MacVICEKit/Sources/" "$SDK_DIR/Sources/"

    rsync -a --delete \
        --exclude ".build" \
        --exclude ".swiftpm" \
        --exclude ".DS_Store" \
        "$REPO_ROOT/MacVICEKit/Tests/" "$SDK_DIR/Tests/"

    cp "$REPO_ROOT/MacVICEKit/README.md" "$SDK_DIR/README.md"
    copy_docc_documentation "$docs_dir"
}

copy_docc_documentation() {
    local docs_dir="$1"
    local archive

    rm -rf "$DOC_DERIVED_DATA"
    (
        cd "$REPO_ROOT/MacVICEKit"
        xcodebuild docbuild \
            -scheme MacVICEKit \
            -destination generic/platform=macOS \
            -derivedDataPath "$DOC_DERIVED_DATA" \
            -quiet
    )

    archive="$(find "$DOC_DERIVED_DATA/Build/Products" -name 'MacVICEKit.doccarchive' -type d -print -quit)"
    if [[ -z "$archive" ]]; then
        echo "MacVICEKit.doccarchive was not produced." >&2
        exit 1
    fi

    rsync -a --delete "$archive/" "$docs_dir/MacVICEKit.doccarchive/"
}

create_runtime_xcframework() {
    rm -rf "$XCFRAMEWORK_DIR"
    xcodebuild -create-xcframework \
        -framework "$FRAMEWORK_DIR" \
        -output "$XCFRAMEWORK_DIR"

    cat > "$SDK_DIR/SDK-README.md" <<EOF
# MacVICEKit $VERSION

This archive is a self-contained MacVICEKit Swift package. MacVICEKit owns and
carries the matching signed MacVICERuntime binary artifact built from the same
MacVICE release.

Contents:

- Package.swift
- Sources/
- Tests/
- Runtime/MacVICERuntime.xcframework
- Documentation/MacVICEKit.doccarchive

Use it from Xcode:

1. Add this folder as a local Swift package.
2. Select the MacVICEKit product.
3. Use runtimeLocation: .automatic.

Users of apps built with this SDK do not need Homebrew, command-line VICE
binaries, or local VICE build tools.
EOF
}

write_manifest() {
    local resources_dir="$FRAMEWORK_DIR/Resources"
    local target
    local first=1

    cat > "$resources_dir/$MANIFEST_NAME" <<EOF
{
  "schemaVersion": 1,
  "artifact": "$FRAMEWORK_NAME",
  "bundleIdentifier": "$FRAMEWORK_IDENTIFIER",
  "version": "$VERSION",
  "minimumMacOSVersion": "$MINIMUM_MACOS_VERSION",
  "architecture": "arm64",
  "macVICEGitSHA": "${VICE_MAC_GIT_SHA:-$(short_git_sha HEAD)}",
  "viceUpstreamGitSHA": "$(upstream_git_sha)",
  "machines": [
EOF

    for target in $MACHINE_TARGETS; do
        if [[ "$first" == 0 ]]; then
            printf ',\n' >> "$resources_dir/$MANIFEST_NAME"
        fi
        first=0
        printf '    "%s"' "$target" >> "$resources_dir/$MANIFEST_NAME"
    done

    cat >> "$resources_dir/$MANIFEST_NAME" <<EOF

  ]
}
EOF
}

sign_framework_payload() {
    local dylib

    for dylib in "$FRAMEWORK_DIR/Frameworks"/*.dylib; do
        if [[ -f "$dylib" ]]; then
            codesign_path "$dylib"
        fi
    done
    codesign_path "$FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"
    codesign_path "$FRAMEWORK_DIR"
}

verify_framework_payload() {
    local dylib

    for dylib in "$FRAMEWORK_DIR/Frameworks"/*.dylib; do
        if [[ -f "$dylib" ]]; then
            codesign --verify --strict --verbose=2 "$dylib"
        fi
    done
    codesign --verify --strict --verbose=2 "$FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"
    codesign --verify --strict --verbose=2 "$FRAMEWORK_DIR"
}

create_sdk_zip() {
    (
        cd "$WORK_DIR"
        ditto -c -k --sequesterRsrc --keepParent "$SDK_NAME" "$SDK_ZIP_PATH"
    )
    cp "$SDK_ZIP_PATH" "$LATEST_SDK_ZIP_PATH"
}

require_tool clang "Install Xcode command line tools."
require_tool codesign "codesign ships with macOS."
require_tool ditto "ditto ships with macOS."
require_tool rsync "rsync ships with macOS."
require_tool xcodebuild "Install Xcode."

if [[ "$SKIP_BUILD" != 1 ]]; then
    VICE_MACOS_MACHINE_TARGETS="$MACHINE_TARGETS" "$SCRIPT_DIR/prepare-vicemac-runtime.sh"
fi

mkdir -p "$DIST_DIR"
create_framework_skeleton
copy_runtime_payload
write_manifest
sign_framework_payload
verify_framework_payload
copy_sdk_payload
create_runtime_xcframework
create_sdk_zip

if [[ "${VICE_MAC_RUNTIME_KEEP_STAGE:-0}" != 1 ]]; then
    rm -rf "$WORK_DIR"
fi

echo "Created $SDK_ZIP_PATH"
echo "Created $LATEST_SDK_ZIP_PATH"

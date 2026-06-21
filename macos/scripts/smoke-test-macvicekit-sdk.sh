#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIST_DIR="${VICE_MAC_SDK_SMOKE_DIST_DIR:-/private/tmp/vice-macos-sdk-smoke-dist}"
WORK_DIR="${VICE_MAC_SDK_SMOKE_WORK_DIR:-/private/tmp/vice-macos-sdk-smoke-work}"
UNZIP_DIR="${VICE_MAC_SDK_SMOKE_UNZIP_DIR:-/private/tmp/vice-macos-sdk-smoke-unzip}"
CONSUMER_DIR="${VICE_MAC_SDK_SMOKE_CONSUMER_DIR:-/private/tmp/vice-macos-sdk-smoke-consumer}"

rm -rf "$DIST_DIR" "$WORK_DIR" "$UNZIP_DIR" "$CONSUMER_DIR"
mkdir -p "$DIST_DIR" "$WORK_DIR" "$UNZIP_DIR" "$CONSUMER_DIR/Sources/SDKSmoke"

export CLANG_MODULE_CACHE_PATH="$WORK_DIR/clang-module-cache"
export SWIFTPM_HOME="$WORK_DIR/swiftpm-home"
export XDG_CACHE_HOME="$WORK_DIR/xdg-cache"

VICE_MAC_RUNTIME_SKIP_BUILD=1 \
VICE_MAC_RUNTIME_WORK_DIR="$WORK_DIR" \
VICE_MAC_DIST_DIR="$DIST_DIR" \
"$SCRIPT_DIR/package-macvicekit-runtime.sh"

ditto -x -k "$DIST_DIR/MacVICEKit-latest-arm64.zip" "$UNZIP_DIR"
SDK_DIR="$(find "$UNZIP_DIR" -maxdepth 1 -type d -name 'MacVICEKit-*-arm64' -print -quit)"

if [[ -z "$SDK_DIR" ]]; then
    echo "Unable to find unzipped MacVICEKit SDK package." >&2
    exit 1
fi

SDK_PACKAGE_BASENAME="$(basename "$SDK_DIR")"

if [[ ! -f "$SDK_DIR/Package.swift" ]]; then
    echo "MacVICEKit SDK is missing Package.swift." >&2
    exit 1
fi

if [[ ! -d "$SDK_DIR/Runtime/MacVICERuntime.xcframework" ]]; then
    echo "MacVICEKit SDK is missing Runtime/MacVICERuntime.xcframework." >&2
    exit 1
fi

if [[ ! -f "$SDK_DIR/LICENSE" ]]; then
    echo "MacVICEKit SDK is missing LICENSE." >&2
    exit 1
fi

if [[ ! -f "$SDK_DIR/NOTICE" ]]; then
    echo "MacVICEKit SDK is missing NOTICE." >&2
    exit 1
fi

swift test --package-path "$SDK_DIR"

cat > "$CONSUMER_DIR/Package.swift" <<EOF
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacVICEKitSDKSmoke",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "$SDK_DIR")
    ],
    targets: [
        .executableTarget(
            name: "SDKSmoke",
            dependencies: [
                .product(name: "MacVICEKit", package: "$SDK_PACKAGE_BASENAME")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
EOF

cat > "$CONSUMER_DIR/Sources/SDKSmoke/main.swift" <<'EOF'
import Foundation
import MacVICEKit

let runtime = try MacVICERuntime.resolve(machine: .c64sc)
let libraryURL = runtime.dynamicLibraryURL(for: .c64sc)

guard libraryURL.lastPathComponent == "libvicemacx64sc.dylib" else {
    fatalError("Resolved unexpected runtime library: \(libraryURL.path)")
}

guard FileManager.default.fileExists(atPath: libraryURL.path) else {
    fatalError("Resolved runtime library does not exist: \(libraryURL.path)")
}

guard FileManager.default.fileExists(atPath: runtime.dataDirectoryURL.path) else {
    fatalError("Resolved VICEData directory does not exist: \(runtime.dataDirectoryURL.path)")
}

print("MacVICEKit SDK resolved \(libraryURL.lastPathComponent)")
EOF

swift run --package-path "$CONSUMER_DIR" SDKSmoke

echo "MacVICEKit SDK smoke test passed."

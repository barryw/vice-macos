#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$MACOS_DIR/ViceMac.xcodeproj"
DEFAULT_DERIVED_DATA="/private/tmp/vice-macos-ci-derived-data"
if [[ -n "${CI_PIPELINE_NUMBER:-}" ]]; then
    DEFAULT_DERIVED_DATA="$DEFAULT_DERIVED_DATA-$CI_PIPELINE_NUMBER"
fi
DERIVED_DATA="${VICE_MAC_CI_DERIVED_DATA:-$DEFAULT_DERIVED_DATA}"
CONFIGURATION="${VICE_MAC_CI_CONFIGURATION:-Debug}"
DESTINATION="${VICE_MAC_CI_DESTINATION:-platform=macOS,arch=arm64}"

swift test --package-path "$MACOS_DIR/../MacVICEKit"
bash "$MACOS_DIR/../MacVICEKit/tools/validate-documentation-examples.sh"
bash -n "$SCRIPT_DIR/package-macvicekit-runtime.sh"
bash -n "$MACOS_DIR/../website/tools/build-macvicekit-docs.sh"
bash -n "$MACOS_DIR/../website/tools/validate-containerfile-pages.sh"
MACVICEKIT_DOC_OUTPUT_DIR="$DERIVED_DATA/MacVICEKitDocs" \
    MACVICEKIT_DOC_DERIVED_DATA="$DERIVED_DATA/MacVICEKitDocBuild" \
    bash "$MACOS_DIR/../website/tools/build-macvicekit-docs.sh"
if [[ ! -f "$DERIVED_DATA/MacVICEKitDocs/documentation/macvicekit/index.html" ]]; then
    echo "MacVICEKit DocC website output is missing its documentation entry point." >&2
    exit 1
fi
bash "$MACOS_DIR/../website/tools/validate-containerfile-pages.sh"

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

APP_PRODUCTS=(
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

verify_built_app_runtime() {
    local app_name="$1"
    local app="$DERIVED_DATA/Build/Products/$CONFIGURATION/$app_name.app"
    local runtime_framework="$app/Contents/Frameworks/MacVICERuntime.framework"

    if [[ ! -d "$runtime_framework" ]]; then
        echo "$app_name.app is missing MacVICERuntime.framework." >&2
        exit 1
    fi

    if [[ ! -d "$runtime_framework/Resources/VICEData" ]]; then
        echo "$app_name.app runtime is missing VICEData." >&2
        exit 1
    fi

    if compgen -G "$app/Contents/Frameworks/libvicemac*.dylib" >/dev/null; then
        echo "$app_name.app still contains loose VICE runtime dylibs." >&2
        exit 1
    fi

    if [[ -d "$app/Contents/Resources/VICEData" ]]; then
        echo "$app_name.app still contains loose VICEData." >&2
        exit 1
    fi
}

for index in "${!SCHEMES[@]}"; do
    scheme="${SCHEMES[$index]}"
    app_name="${APP_PRODUCTS[$index]}"

    xcodebuild \
        -project "$PROJECT" \
        -scheme "$scheme" \
        -configuration "$CONFIGURATION" \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build

    verify_built_app_runtime "$app_name"
done

xcodebuild \
    test \
    -project "$PROJECT" \
    -scheme "VICE Mac Tests" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA"

bash "$SCRIPT_DIR/smoke-test-macvicekit-sdk.sh"
bash "$SCRIPT_DIR/test-release-notes.sh"

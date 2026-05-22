#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
VICE_SRC="$REPO_ROOT/vice"
BUILD_DIR="${VICE_MACOS_ENGINE_BUILD_DIR:-/private/tmp/vice-macos-native-build}"
PRODUCTS_DIR="$MACOS_DIR/BuildProducts"
read -r -a MACHINE_TARGETS <<< "${VICE_MACOS_MACHINE_TARGETS:-x64sc}"

export PATH="/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$PATH"

mkdir -p "$BUILD_DIR" "$PRODUCTS_DIR"

latest_macos_runtime_target() {
    sw_vers -productVersion | awk -F. '{ print $1 "." $2 }'
}

ENGINE_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-$(latest_macos_runtime_target)}"
export MACOSX_DEPLOYMENT_TARGET="$ENGINE_DEPLOYMENT_TARGET"

needs_autogen=0
if [[ ! -x "$VICE_SRC/configure" || "$VICE_SRC/configure.ac" -nt "$VICE_SRC/configure" ]]; then
    needs_autogen=1
fi

for makefile_am in \
    "$VICE_SRC/src/Makefile.am" \
    "$VICE_SRC/src/arch/Makefile.am" \
    "$VICE_SRC/src/arch/shared/Makefile.am" \
    "$VICE_SRC/src/arch/macos/Makefile.am"; do
    makefile_in="${makefile_am%.am}.in"
    if [[ ! -f "$makefile_in" || "$makefile_am" -nt "$makefile_in" ]]; then
        needs_autogen=1
        break
    fi
done

if [[ "$needs_autogen" == 1 ]]; then
    (cd "$VICE_SRC" && ./autogen.sh)
fi

require_build_tool() {
    local tool="$1"
    local install_hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required build tool '$tool' is missing." >&2
        echo "$install_hint" >&2
        echo "Current PATH: $PATH" >&2
        exit 1
    fi
}

short_git_sha() {
    local repo="$1"
    local ref="$2"

    git -C "$repo" rev-parse --short=12 "$ref" 2>/dev/null || echo "unknown"
}

mac_git_sha() {
    local sha

    if [[ -n "${VICE_MAC_GIT_SHA:-}" ]]; then
        echo "$VICE_MAC_GIT_SHA"
        return
    fi

    sha="$(short_git_sha "$REPO_ROOT" HEAD)"
    if [[ "$sha" != "unknown" && -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
        sha="${sha}-dirty"
    fi

    echo "$sha"
}

upstream_git_sha() {
    local merge_base
    local parents

    if [[ -n "${VICE_UPSTREAM_GIT_SHA:-}" ]]; then
        echo "$VICE_UPSTREAM_GIT_SHA"
        return
    fi

    merge_base="$(git -C "$REPO_ROOT" merge-base HEAD upstream/main 2>/dev/null || true)"
    if [[ -n "$merge_base" ]]; then
        short_git_sha "$REPO_ROOT" "$merge_base"
        return
    fi

    parents="$(git -C "$REPO_ROOT" log --merges --first-parent --format=%P -n 1 HEAD 2>/dev/null || true)"
    set -- $parents
    if [[ $# -ge 2 ]]; then
        short_git_sha "$REPO_ROOT" "$2"
        return
    fi

    echo "unknown"
}

write_plist_string() {
    local plist="$1"
    local key="$2"
    local value="$3"

    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
}

write_build_metadata() {
    local info_plist

    if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${INFOPLIST_PATH:-}" ]]; then
        return
    fi

    info_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
    if [[ ! -f "$info_plist" ]]; then
        echo "Built app Info.plist is missing at $info_plist" >&2
        exit 1
    fi

    write_plist_string "$info_plist" "VICEMacGitSHA" "$(mac_git_sha)"
    write_plist_string "$info_plist" "VICEUpstreamGitSHA" "$(upstream_git_sha)"
}

if [[ -f "$BUILD_DIR/src/Makefile" ]]; then
    configured_target="$(grep -m 1 -Eo -- '-mmacosx-version-min=[0-9.]+' "$BUILD_DIR/src/Makefile" | sed 's/.*=//' || true)"
    if [[ "$configured_target" != "$ENGINE_DEPLOYMENT_TARGET" ||
          "$VICE_SRC/configure" -nt "$BUILD_DIR/Makefile" ||
          "$VICE_SRC/src/Makefile.in" -nt "$BUILD_DIR/src/Makefile" ||
          "$VICE_SRC/src/arch/Makefile.in" -nt "$BUILD_DIR/src/arch/Makefile" ||
          "$VICE_SRC/src/arch/shared/Makefile.in" -nt "$BUILD_DIR/src/arch/shared/Makefile" ||
          "$VICE_SRC/src/arch/macos/Makefile.in" -nt "$BUILD_DIR/src/arch/macos/Makefile" ]]; then
        make -C "$BUILD_DIR" distclean
    fi
fi

if [[ ! -f "$BUILD_DIR/Makefile" || ! -f "$BUILD_DIR/src/arch/macos/Makefile" ]]; then
    require_build_tool "dos2unix" "Install it with: brew install dos2unix"

    (cd "$BUILD_DIR" && "$VICE_SRC/configure" \
        --enable-macosui \
        --enable-macos-minimum-version="$ENGINE_DEPLOYMENT_TARGET" \
        --disable-pdf-docs \
        --disable-html-docs \
        --without-pulse \
        --without-alsa \
        --without-oss)
fi

SOUND_DRIVER_MAKEFILE="$BUILD_DIR/src/arch/shared/sounddrv/Makefile"
if ! grep -Eq '^SOUND_DRIVERS = .*soundcoreaudio\.o' "$SOUND_DRIVER_MAKEFILE"; then
    echo "CoreAudio sound driver was not enabled by the VICE configure step." >&2
    exit 1
fi

for framework in CoreAudio AudioToolbox AudioUnit; do
    if ! grep -Eq "^SOUND_LIBS = .*${framework}" "$SOUND_DRIVER_MAKEFILE"; then
        echo "$framework link flags are missing from the VICE sound build." >&2
        exit 1
    fi
done

make -C "$BUILD_DIR/src" gcr.o V=1
make -C "$BUILD_DIR/src/drive" V=1
make -C "$BUILD_DIR/src/vdrive" V=1
make -C "$BUILD_DIR/src/arch/macos" V=1
make -C "$BUILD_DIR/src/lib/linenoise-ng" V=1

codesign_dylib() {
    local dylib="$1"
    local identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"

    if [[ -z "$identity" ]]; then
        identity="-"
    fi

    codesign --force --sign "$identity" --timestamp=none "$dylib"
}

for machine_target in "${MACHINE_TARGETS[@]}"; do
    dylib_name="libvicemac${machine_target}.dylib"
    dylib_path="$PRODUCTS_DIR/$dylib_name"
    link_log="/private/tmp/vice-macos-native-${machine_target}.log"

    rm -f "$BUILD_DIR/src/$machine_target"
    make -C "$BUILD_DIR/src" "$machine_target" V=1 > "$link_log" 2>&1

    link_command="$(grep " -o $machine_target " "$link_log" | tail -n 1 || true)"
    if [[ -z "$link_command" ]]; then
        tail -n 80 "$link_log" >&2
        echo "Unable to find $machine_target link command in $link_log" >&2
        exit 1
    fi

    dylib_command="${link_command/ -o $machine_target / -dynamiclib -install_name @rpath\/$dylib_name -o $dylib_path }"
    (cd "$BUILD_DIR/src" && eval "$dylib_command")

    codesign_dylib "$dylib_path"

    if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
        mkdir -p "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
        cp "$dylib_path" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$dylib_name"
        codesign_dylib "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$dylib_name"
    fi
done


if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData"
    rsync -a --delete "$VICE_SRC/data/" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData/"
fi

write_build_metadata

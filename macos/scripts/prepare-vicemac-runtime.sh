#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
VICE_SRC="$REPO_ROOT/vice"
BUILD_DIR="${VICE_MACOS_ENGINE_BUILD_DIR:-/private/tmp/vice-macos-native-build}"
PRODUCTS_DIR="$MACOS_DIR/BuildProducts"
DYLIB_NAME="libvicemacx64sc.dylib"
DYLIB_PATH="$PRODUCTS_DIR/$DYLIB_NAME"
LINK_LOG="/private/tmp/vice-macos-native-x64sc.log"

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

make -C "$BUILD_DIR/src/arch/macos" V=1
make -C "$BUILD_DIR/src/lib/linenoise-ng" V=1

rm -f "$BUILD_DIR/src/x64sc"
make -C "$BUILD_DIR/src" x64sc V=1 > "$LINK_LOG" 2>&1

link_command="$(grep ' -o x64sc ' "$LINK_LOG" | tail -n 1 || true)"
if [[ -z "$link_command" ]]; then
    tail -n 80 "$LINK_LOG" >&2
    echo "Unable to find x64sc link command in $LINK_LOG" >&2
    exit 1
fi

dylib_command="${link_command/ -o x64sc / -dynamiclib -install_name @rpath\/$DYLIB_NAME -o $DYLIB_PATH }"
(cd "$BUILD_DIR/src" && eval "$dylib_command")

if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
    mkdir -p "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
    cp "$DYLIB_PATH" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$DYLIB_NAME"
fi

if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData"
    rsync -a --delete "$VICE_SRC/data/" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData/"
fi

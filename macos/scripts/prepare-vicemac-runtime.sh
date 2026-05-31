#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
VICE_SRC="$REPO_ROOT/vice"

default_engine_build_dir() {
    local repo_hash

    repo_hash="$(printf '%s' "$REPO_ROOT" | /usr/bin/shasum -a 256 | awk '{ print substr($1, 1, 12) }')"
    echo "/private/tmp/vice-macos-native-build-$repo_hash"
}

BUILD_DIR="${VICE_MACOS_ENGINE_BUILD_DIR:-$(default_engine_build_dir)}"
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

short_git_sha_value() {
    local repo="$1"
    local value="$2"
    local short_value

    short_value="$(git -C "$repo" rev-parse --short=12 "$value" 2>/dev/null || true)"
    if [[ -n "$short_value" ]]; then
        echo "$short_value"
        return
    fi

    printf '%s\n' "${value:0:12}"
}

mac_git_sha() {
    local sha

    if [[ -n "${VICE_MAC_GIT_SHA:-}" ]]; then
        echo "$VICE_MAC_GIT_SHA"
        return
    fi

    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        short_git_sha_value "$REPO_ROOT" "$CI_COMMIT_SHA"
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
            short_git_sha "$REPO_ROOT" "$merge_base"
            return
        fi
    done

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
    local metadata_plist
    local mac_sha
    local upstream_sha

    mac_sha="$(mac_git_sha)"
    upstream_sha="$(upstream_git_sha)"

    if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
        metadata_plist="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEBuildMetadata.plist"
        mkdir -p "$(dirname "$metadata_plist")"
        cat > "$metadata_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>VICEMacGitSHA</key>
    <string>$mac_sha</string>
    <key>VICEUpstreamGitSHA</key>
    <string>$upstream_sha</string>
</dict>
</plist>
EOF
    fi

    if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${INFOPLIST_PATH:-}" ]]; then
        return
    fi

    info_plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
    if [[ ! -f "$info_plist" ]]; then
        echo "Built app Info.plist is not available yet; wrote VICEBuildMetadata.plist instead." >&2
        return
    fi

    write_plist_string "$info_plist" "VICEMacGitSHA" "$mac_sha"
    write_plist_string "$info_plist" "VICEUpstreamGitSHA" "$upstream_sha"
}

if [[ -f "$BUILD_DIR/src/Makefile" ]]; then
    configured_target="$(grep -m 1 -Eo -- '-mmacosx-version-min=[0-9.]+' "$BUILD_DIR/src/Makefile" | sed 's/.*=//' || true)"
    configured_source="$(sed -n 's/^top_srcdir = //p' "$BUILD_DIR/src/Makefile" | head -n 1)"
    if [[ "$configured_source" != "$VICE_SRC" ]]; then
        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"
    elif [[ "$configured_target" != "$ENGINE_DEPLOYMENT_TARGET" ||
          "$VICE_SRC/configure" -nt "$BUILD_DIR/Makefile" ||
          "$VICE_SRC/src/Makefile.in" -nt "$BUILD_DIR/src/Makefile" ||
          "$VICE_SRC/src/arch/Makefile.in" -nt "$BUILD_DIR/src/arch/Makefile" ||
          "$VICE_SRC/src/arch/shared/Makefile.in" -nt "$BUILD_DIR/src/arch/shared/Makefile" ||
          "$VICE_SRC/src/arch/macos/Makefile.in" -nt "$BUILD_DIR/src/arch/macos/Makefile" ]]; then
        make -C "$BUILD_DIR" distclean
    fi
fi

require_build_tool "install_name_tool" "Install Xcode command line tools."

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
make -C "$BUILD_DIR/src/fsdevice" V=1
make -C "$BUILD_DIR/src/userport" V=1
make -C "$BUILD_DIR/src/core/rtc" V=1
make -C "$BUILD_DIR/src/arch/macos" V=1
make -C "$BUILD_DIR/src/lib/linenoise-ng" V=1
make -C "$BUILD_DIR/src/lib/md5" V=1
if [[ ! -f "$BUILD_DIR/src/monitor/mon_parse.h" ]]; then
    rm -f "$BUILD_DIR/src/monitor/mon_parse.c"
fi
make -C "$BUILD_DIR/src/monitor" mon_parse.c mon_lex.c V=1

codesign_dylib() {
    local dylib="$1"
    local identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
    local codesign_args

    if [[ -z "$identity" ]]; then
        identity="-"
    fi

    codesign_args=(--force)
    if [[ -n "${VICE_MAC_CODESIGN_KEYCHAIN:-}" ]]; then
        codesign_args+=(--keychain "$VICE_MAC_CODESIGN_KEYCHAIN")
    fi

    if [[ "$identity" != "-" ]]; then
        codesign_args+=(--options runtime --sign "$identity" --timestamp "$dylib")
    else
        codesign_args+=(--sign "$identity" --timestamp=none "$dylib")
    fi

    codesign "${codesign_args[@]}"
}

is_system_dylib_dependency() {
    local dependency="$1"

    case "$dependency" in
        /System/Library/*|/usr/lib/*|@rpath/*|@loader_path/*|@executable_path/*)
            return 0
            ;;
    esac

    return 1
}

dylib_dependencies() {
    local binary="$1"

    otool -L "$binary" |
        sed '1d; s/^[[:space:]]*//; s/[[:space:]]*(.*//'
}

rewrite_dependency_load_paths() {
    local binary="$1"
    local frameworks_dir="$2"
    local binary_name
    local dependency
    local dependency_name
    local bundled_dependency

    binary_name="$(basename "$binary")"
    while IFS= read -r dependency; do
        if [[ -z "$dependency" ]] || is_system_dylib_dependency "$dependency"; then
            continue
        fi

        dependency_name="$(basename "$dependency")"
        if [[ "$dependency_name" == "$binary_name" ]]; then
            continue
        fi

        bundled_dependency="$frameworks_dir/$dependency_name"
        if [[ ! -f "$bundled_dependency" ]]; then
            echo "Expected bundled runtime dependency is missing: $bundled_dependency" >&2
            exit 1
        fi

        install_name_tool -change "$dependency" "@rpath/$dependency_name" "$binary"
    done < <(dylib_dependencies "$binary")
}

bundle_runtime_dependencies() {
    local binary="$1"
    local frameworks_dir="$2"
    local binary_name
    local dependency
    local dependency_name
    local bundled_dependency

    binary_name="$(basename "$binary")"
    while IFS= read -r dependency; do
        if [[ -z "$dependency" ]] || is_system_dylib_dependency "$dependency"; then
            continue
        fi

        if [[ ! -f "$dependency" ]]; then
            echo "Runtime dependency is missing: $dependency" >&2
            exit 1
        fi

        dependency_name="$(basename "$dependency")"
        if [[ "$dependency_name" == "$binary_name" ]]; then
            continue
        fi

        bundled_dependency="$frameworks_dir/$dependency_name"

        if [[ "$dependency" != "$bundled_dependency" ]]; then
            cp "$dependency" "$bundled_dependency"
            chmod u+w "$bundled_dependency"
        fi

        bundle_runtime_dependencies "$bundled_dependency" "$frameworks_dir"
        rewrite_dependency_load_paths "$bundled_dependency" "$frameworks_dir"
        install_name_tool -id "@rpath/$dependency_name" "$bundled_dependency"
        codesign_dylib "$bundled_dependency"
    done < <(dylib_dependencies "$binary")

    rewrite_dependency_load_paths "$binary" "$frameworks_dir"
}

copy_prepared_runtime_dependencies() {
    local source_dir="$1"
    local frameworks_dir="$2"
    local dependency
    local dependency_name
    local copied_dependency

    for dependency in "$source_dir"/*.dylib; do
        if [[ ! -f "$dependency" ]]; then
            continue
        fi

        dependency_name="$(basename "$dependency")"
        case "$dependency_name" in
            libvicemac*.dylib)
                continue
                ;;
        esac

        copied_dependency="$frameworks_dir/$dependency_name"
        cp "$dependency" "$copied_dependency"
        chmod u+w "$copied_dependency"
        codesign_dylib "$copied_dependency"
    done
}

build_machine_runtime_libraries() {
    local machine_target="$1"

    case "$machine_target" in
        x64sc)
            make -C "$BUILD_DIR/src/c64" V=1
            ;;
        vsid)
            make -C "$BUILD_DIR/src/c64" V=1
            ;;
        x128)
            make -C "$BUILD_DIR/src/c64" V=1
            make -C "$BUILD_DIR/src/c128" V=1
            ;;
        xvic)
            make -C "$BUILD_DIR/src/vic20" V=1
            ;;
        xpet)
            make -C "$BUILD_DIR/src/pet" V=1
            ;;
        xplus4|xc16|xc232|xv364)
            make -C "$BUILD_DIR/src/plus4" V=1
            ;;
    esac
}

for machine_target in "${MACHINE_TARGETS[@]}"; do
    dylib_name="libvicemac${machine_target}.dylib"
    dylib_path="$PRODUCTS_DIR/$dylib_name"
    link_log="/private/tmp/vice-macos-native-${machine_target}.log"

    build_machine_runtime_libraries "$machine_target"

    rm -f "$BUILD_DIR/src/$machine_target"
    if ! make -C "$BUILD_DIR/src" "$machine_target" V=1 > "$link_log" 2>&1; then
        tail -n 120 "$link_log" >&2
        exit 1
    fi

    link_command="$(grep " -o $machine_target " "$link_log" | tail -n 1 || true)"
    if [[ -z "$link_command" ]]; then
        tail -n 80 "$link_log" >&2
        echo "Unable to find $machine_target link command in $link_log" >&2
        exit 1
    fi

    dylib_command="${link_command/ -o $machine_target / -dynamiclib -install_name @rpath\/$dylib_name -o $dylib_path }"
    (cd "$BUILD_DIR/src" && eval "$dylib_command")

    bundle_runtime_dependencies "$dylib_path" "$PRODUCTS_DIR"
    codesign_dylib "$dylib_path"

    if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
        mkdir -p "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
        cp "$dylib_path" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$dylib_name"
        copy_prepared_runtime_dependencies "$PRODUCTS_DIR" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
        bundle_runtime_dependencies "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$dylib_name" \
            "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
        codesign_dylib "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/$dylib_name"
    fi
done


if [[ -n "${TARGET_BUILD_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
    mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData"
    rsync -a --delete "$VICE_SRC/data/" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/VICEData/"
fi

write_build_metadata

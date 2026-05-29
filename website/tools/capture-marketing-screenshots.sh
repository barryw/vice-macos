#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="${VICE_MAC_SCREENSHOT_APP_DIR:-/private/tmp/vice-macos-website-shots/Build/Products/Debug}"
OUT_DIR="$ROOT_DIR/website/assets/screenshots"
RAW_OUT_DIR="${VICE_MAC_SCREENSHOT_RAW_DIR:-/private/tmp/vice-macos-website-screenshots-raw}"
WINDOW_ID_SCRIPT="$ROOT_DIR/website/tools/window-id.swift"
SCREENSHOT_ONLY="${1:-${VICE_MAC_SCREENSHOT_ONLY:-}}"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/vice-macos-website-swift-module-cache}"

mkdir -p "$OUT_DIR"
mkdir -p "$RAW_OUT_DIR"

safe_open() {
    /usr/bin/env -i \
        "HOME=$HOME" \
        "USER=${USER:-$(id -un)}" \
        "LOGNAME=${LOGNAME:-$(id -un)}" \
        "PATH=/usr/bin:/bin:/usr/sbin:/sbin" \
        /usr/bin/open "$@"
}

quit_app() {
    local process_name="$1"
    osascript - "$process_name" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
    tell application "System Events"
        set processName to item 1 of argv
        if exists process processName then
            tell process processName to set frontmost to true
            keystroke "q" using command down
        end if
    end tell
end run
APPLESCRIPT
    sleep 0.8
}

wait_for_window() {
    local process_name="$1"
    local title="${2:-}"

    for _ in {1..80}; do
        if swift "$WINDOW_ID_SCRIPT" "$process_name" "$title" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.25
    done

    echo "Timed out waiting for window: $process_name $title" >&2
    return 1
}

set_window_bounds() {
    local process_name="$1"
    local title="$2"
    local x="$3"
    local y="$4"
    local width="$5"
    local height="$6"

    osascript - "$process_name" "$title" "$x" "$y" "$width" "$height" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    set titleNeedle to item 2 of argv
    set xPos to (item 3 of argv) as integer
    set yPos to (item 4 of argv) as integer
    set windowWidth to (item 5 of argv) as integer
    set windowHeight to (item 6 of argv) as integer

    tell application "System Events"
        tell process processName
            set frontmost to true
            repeat until (count of windows) > 0
                delay 0.1
            end repeat

            if titleNeedle is "" then
                set targetWindow to window 1
            else
                set targetWindow to missing value
                repeat with candidate in windows
                    if (name of candidate) contains titleNeedle then
                        set targetWindow to candidate
                        exit repeat
                    end if
                end repeat
                if targetWindow is missing value then set targetWindow to window 1
            end if

            set position of targetWindow to {xPos, yPos}
            set size of targetWindow to {windowWidth, windowHeight}
        end tell
    end tell
end run
APPLESCRIPT
    sleep 0.4
}

capture_window() {
    local process_name="$1"
    local title="$2"
    local output_name="$3"
    local window_id

    window_id="$(swift "$WINDOW_ID_SCRIPT" "$process_name" "$title")"
    screencapture -x -l "$window_id" "$RAW_OUT_DIR/$output_name"
}

make_web_copy() {
    local source_name="$1"
    local max_size="$2"

    sips -Z "$max_size" "$RAW_OUT_DIR/$source_name" --out "$OUT_DIR/$source_name" >/dev/null
}

find_downloads_disk_image() {
    local skip="${1:-}"
    local candidate

    while IFS= read -r candidate; do
        if [[ -z "$skip" || "$candidate" != "$skip" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done < <(find "$HOME/Downloads" -maxdepth 3 -type f \( -iname '*.d64' -o -iname '*.d71' -o -iname '*.d81' -o -iname '*.d80' -o -iname '*.d82' -o -iname '*.d67' \) -print | sort)

    return 1
}

find_hvsc_showcase_disk() {
    local explicit="${VICE_MAC_SCREENSHOT_HVSC_DISK:-}"
    local candidate

    if [[ -n "$explicit" && -f "$explicit" ]]; then
        printf '%s\n' "$explicit"
        return 0
    fi

    for candidate in \
        "$HOME/Downloads/20_Years_HVSC.d64" \
        "$HOME/20_Years_HVSC.d64" \
        "$HOME/Downloads/HVSC_Intro_41.d64" \
        "$HOME/HVSC_Intro_41.d64"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

find_geos128_showcase_disk() {
    local explicit="${VICE_MAC_SCREENSHOT_GEOS128_DISK:-}"
    local candidate

    if [[ -n "$explicit" && -f "$explicit" ]]; then
        printf '%s\n' "$explicit"
        return 0
    fi

    for candidate in \
        "$HOME/Downloads/geos128-v2/GEOS128-V2-Disks/GEOS128-1351.D64" \
        "$HOME/Downloads/geos128-v2/GEOS128-V2-Disks/GEOS128.D64"; do
        if [[ -f "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

paste_into_emulator() {
    local process_name="$1"
    local text="$2"

    osascript - "$process_name" "$text" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    set pasteText to item 2 of argv
    set the clipboard to pasteText
    tell application "System Events"
        tell process processName
            set frontmost to true
            keystroke "v" using {command down, option down}
        end tell
    end tell
end run
APPLESCRIPT
    sleep 1.6
}

open_media_with_app() {
    local process_name="$1"
    local media_path="$2"

    osascript - "$process_name" "$media_path" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    set mediaPath to item 2 of argv
    set the clipboard to mediaPath
    tell application "System Events"
        tell process processName
            set frontmost to true
            keystroke "o" using command down
            delay 0.5
            keystroke "g" using {command down, shift down}
            delay 0.2
            keystroke "v" using command down
            delay 0.2
            key code 36
            delay 0.5
            key code 36
        end tell
    end tell
end run
APPLESCRIPT
    sleep 1.4
}

open_settings() {
    local process_name="$1"
    local bundle_id="$2"
    local pane_id="$3"
    local pane_title="$4"
    local output_name="$5"

    defaults write "$bundle_id" vice.settings.selectedPane "$pane_id"

    osascript - "$process_name" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    tell application "System Events"
        tell process processName
            set frontmost to true
            keystroke "," using command down
        end tell
    end tell
end run
APPLESCRIPT

    wait_for_window "$process_name" "$pane_title"
    set_window_bounds "$process_name" "$pane_title" 110 95 920 680
    capture_window "$process_name" "$pane_title" "$output_name"
}

capture_machine() {
    local app_name="$1"
    local bundle_id="$2"
    local output_name="$3"
    local paste_text="${4:-}"

    quit_app "$app_name"
    safe_open -n "$APP_DIR/$app_name.app"
    wait_for_window "$app_name" ""
    set_window_bounds "$app_name" "" 90 80 930 700
    sleep 2.0

    if [[ -n "$paste_text" ]]; then
        paste_into_emulator "$app_name" "$paste_text"
    fi

    capture_window "$app_name" "" "$output_name"
}

capture_machine_showcase() {
    local app_name="$1"
    local bundle_id="$2"
    local output_name="$3"
    local media_path="$4"
    local paste_text="${5:-}"
    local wait_after_paste="${6:-8}"

    quit_app "$app_name"
    safe_open -n "$APP_DIR/$app_name.app"
    wait_for_window "$app_name" ""
    set_window_bounds "$app_name" "" 90 80 930 700
    sleep 2.0

    open_media_with_app "$app_name" "$media_path"

    if [[ -n "$paste_text" ]]; then
        paste_into_emulator "$app_name" "$paste_text"
    fi

    sleep "$wait_after_paste"
    capture_window "$app_name" "" "$output_name"
}

capture_x64sc_hvsc_showcase() {
    local hvsc_disk
    local load_command
    local load_wait=42
    local run_wait=18

    hvsc_disk="$(find_hvsc_showcase_disk || true)"
    if [[ -z "$hvsc_disk" ]]; then
        echo "No HVSC showcase disk found; skipping x64sc HVSC screenshot." >&2
        return 0
    fi

    case "$(basename "$hvsc_disk")" in
        20_Years_HVSC.d64)
            load_command=$'LOAD"-HVSC 20 YEARS!-",8,1\n'
            load_wait=115
            run_wait=35
            ;;
        *)
            load_command=$'LOAD"HVSC INTRO",8,1\n'
            ;;
    esac

    quit_app "x64sc"
    safe_open -n "$APP_DIR/x64sc.app"
    wait_for_window "x64sc" ""
    set_window_bounds "x64sc" "" 90 80 930 700
    sleep 2.0

    open_media_with_app "x64sc" "$hvsc_disk"
    paste_into_emulator "x64sc" "$load_command"
    sleep "$load_wait"
    paste_into_emulator "x64sc" $'RUN\n'
    sleep "$run_wait"
    capture_window "x64sc" "" "x64sc-hvsc.png"
    quit_app "x64sc"
}

capture_x128_geos_showcase() {
    local geos_disk

    geos_disk="$(find_geos128_showcase_disk || true)"
    if [[ -z "$geos_disk" ]]; then
        echo "No GEOS 128 disk found; skipping x128 GEOS screenshot." >&2
        return 0
    fi

    defaults write "com.barrywalker.vicemac.c128" "vice.displayOutput.x128" "c128.80Column"

    capture_machine_showcase "x128" \
        "com.barrywalker.vicemac.c128" \
        "x128-geos.png" \
        "$geos_disk" \
        $'LOAD"GEOS128",8,1\nRUN\n' \
        46
    quit_app "x128"
}

open_disk_image_manager() {
    local process_name="$1"

    osascript - "$process_name" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    tell application "System Events"
        tell process processName
            set frontmost to true
            keystroke "d" using {command down, shift down}
        end tell
    end tell
end run
APPLESCRIPT
}

present_new_disk_sheet() {
    local process_name="$1"

    osascript - "$process_name" <<'APPLESCRIPT'
on run argv
    set processName to item 1 of argv
    tell application "System Events"
        tell process processName
            set frontmost to true
            keystroke "n" using command down
        end tell
    end tell
end run
APPLESCRIPT

    sleep 0.8
}

capture_disk_image_manager() {
    local left_disk="${VICE_MAC_SCREENSHOT_D64_LEFT:-}"
    local right_disk="${VICE_MAC_SCREENSHOT_D64_RIGHT:-}"

    if [[ -z "$left_disk" ]]; then
        left_disk="$(find_downloads_disk_image || true)"
    fi

    if [[ -z "$left_disk" ]]; then
        echo "No disk image found in ~/Downloads; skipping disk manager screenshots." >&2
        return 0
    fi

    quit_app "x64sc"
    safe_open -n \
        --env VICE_MAC_DISK_MANAGER_SCREENSHOT=1 \
        --env "VICE_MAC_DISK_MANAGER_LEFT=$left_disk" \
        --env "VICE_MAC_DISK_MANAGER_RIGHT=$right_disk" \
        "$APP_DIR/x64sc.app"

    wait_for_window "x64sc" ""
    open_disk_image_manager "x64sc"
    wait_for_window "x64sc" "Disk Image Manager"
    set_window_bounds "x64sc" "Disk Image Manager" 65 70 1320 860
    sleep 1.2
    capture_window "x64sc" "Disk Image Manager" "disk-manager-files.png"

    present_new_disk_sheet "x64sc"
    capture_window "x64sc" "Disk Image Manager" "disk-manager-new-image.png"

    quit_app "x64sc"
}

if [[ "$SCREENSHOT_ONLY" == "disk-manager" ]]; then
    capture_disk_image_manager
    make_web_copy "disk-manager-files.png" 1600
    make_web_copy "disk-manager-new-image.png" 1200
    echo "Captured screenshots in $OUT_DIR"
    exit 0
fi

if [[ "$SCREENSHOT_ONLY" == "showcase" ]]; then
    capture_x64sc_hvsc_showcase
    capture_x128_geos_showcase
    make_web_copy "x64sc-hvsc.png" 1800
    make_web_copy "x128-geos.png" 1800
    echo "Captured screenshots in $OUT_DIR"
    exit 0
fi

if [[ "$SCREENSHOT_ONLY" == "x64sc-showcase" ]]; then
    capture_x64sc_hvsc_showcase
    make_web_copy "x64sc-hvsc.png" 1800
    echo "Captured screenshots in $OUT_DIR"
    exit 0
fi

capture_x64sc_hvsc_showcase

capture_disk_image_manager

capture_x128_geos_showcase

capture_machine "xvic" "com.barrywalker.vicemac.vic20" "xvic-basic.png" $'10 PRINT "VIC-20 ON MAC"\n20 PRINT "REAL VICE CORE"\nRUN\n'
quit_app "xvic"

capture_machine "xpet" "com.barrywalker.vicemac.pet" "xpet-basic.png" $'10 PRINT "PET 4032"\n20 PRINT "NATIVE SETTINGS"\nRUN\n'
quit_app "xpet"

capture_machine "xplus4" "com.barrywalker.vicemac.plus4" "xplus4-basic.png" $'10 PRINT "PLUS/4 FAMILY"\n20 PRINT "TED VIDEO"\nRUN\n'
quit_app "xplus4"

make_web_copy "x64sc-hvsc.png" 1800
make_web_copy "disk-manager-files.png" 1600
make_web_copy "disk-manager-new-image.png" 1200
make_web_copy "x128-geos.png" 1800
make_web_copy "xvic-basic.png" 1400
make_web_copy "xpet-basic.png" 1400
make_web_copy "xplus4-basic.png" 1400

echo "Captured screenshots in $OUT_DIR"

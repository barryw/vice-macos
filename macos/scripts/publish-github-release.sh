#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MACOS_DIR/.." && pwd)"
DIST_DIR="${VICE_MAC_DIST_DIR:-$MACOS_DIR/dist}"
DERIVED_DATA="${VICE_MAC_RELEASE_DERIVED_DATA:-/private/tmp/vice-macos-release-derived-data}"
CONFIGURATION="${VICE_MAC_RELEASE_CONFIGURATION:-Release}"
SPARKLE_SIGN_UPDATE="${SPARKLE_SIGN_UPDATE:-}"
SPARKLE_PRIVATE_KEY="${SPARKLE_PRIVATE_KEY:-}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/barryw/vice-macos/releases/latest/download/appcast.xml}"

require_tool() {
    local tool="$1"
    local hint="$2"

    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' is missing." >&2
        echo "$hint" >&2
        exit 1
    fi
}

release_repo() {
    echo "${CI_REPO:-barryw/vice-macos}"
}

release_tag() {
    if [[ -n "${VICE_MAC_RELEASE_TAG:-}" ]]; then
        echo "$VICE_MAC_RELEASE_TAG"
        return
    fi

    if [[ -n "${CI_COMMIT_TAG:-}" ]]; then
        echo "$CI_COMMIT_TAG"
        return
    fi

    "$SCRIPT_DIR/compute-vicemac-version.sh"
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

    git -C "$REPO_ROOT" show -s --format=%ct HEAD
}

github_repo_args() {
    if [[ -n "${CI_REPO:-}" ]]; then
        echo "--repo=$CI_REPO"
    fi
}

release_target_args() {
    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        echo "--target=$CI_COMMIT_SHA"
    fi
}

xml_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\&apos;/g"
}

cdata_escape() {
    sed 's/]]>/]]]]><![CDATA[>/g'
}

normalize_system_version() {
    local version="$1"

    case "$version" in
        *.*.*)
            echo "$version"
            ;;
        *.*)
            echo "$version.0"
            ;;
        *)
            echo "$version.0.0"
            ;;
    esac
}

minimum_system_version() {
    local app_info="$DERIVED_DATA/Build/Products/$CONFIGURATION/x64sc.app/Contents/Info.plist"
    local version=""

    if [[ -n "${SPARKLE_MINIMUM_SYSTEM_VERSION:-}" ]]; then
        normalize_system_version "$SPARKLE_MINIMUM_SYSTEM_VERSION"
        return
    fi

    if [[ -f "$app_info" ]]; then
        version="$(plutil -extract LSMinimumSystemVersion raw -o - "$app_info" 2>/dev/null || true)"
    fi

    if [[ -z "$version" ]]; then
        version="$(sed -n 's/^[[:space:]]*MACOSX_DEPLOYMENT_TARGET = \([^;][^;]*\);/\1/p' "$MACOS_DIR/ViceMac.xcodeproj/project.pbxproj" | head -n 1)"
    fi

    if [[ -z "$version" ]]; then
        return
    fi

    normalize_system_version "$version"
}

find_sparkle_sign_update() {
    local root
    local tool

    if [[ -n "$SPARKLE_SIGN_UPDATE" ]]; then
        if [[ -x "$SPARKLE_SIGN_UPDATE" ]]; then
            echo "$SPARKLE_SIGN_UPDATE"
            return
        fi

        echo "Configured SPARKLE_SIGN_UPDATE is not executable: $SPARKLE_SIGN_UPDATE" >&2
        exit 1
    fi

    for root in "$DERIVED_DATA" "$HOME/Library/Developer/Xcode/DerivedData"; do
        if [[ ! -d "$root" ]]; then
            continue
        fi

        tool="$(find "$root" -path '*/Sparkle/bin/sign_update' -type f -perm +111 -print -quit 2>/dev/null || true)"
        if [[ -n "$tool" ]]; then
            echo "$tool"
            return
        fi
    done

    echo "Sparkle sign_update tool was not found." >&2
    echo "Run the package step first, or set SPARKLE_SIGN_UPDATE to Sparkle/bin/sign_update." >&2
    exit 1
}

sign_sparkle_artifact() {
    local artifact="$1"
    local sign_update="$2"

    if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
        "$sign_update" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$artifact"
        return
    fi

    if [[ -n "$SPARKLE_PRIVATE_KEY" ]]; then
        printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sign_update" --ed-key-file - "$artifact"
        return
    fi

    echo "Missing Sparkle private key." >&2
    echo "Set SPARKLE_PRIVATE_KEY_FILE or SPARKLE_PRIVATE_KEY." >&2
    exit 1
}

write_release_notes() {
    local tag="$1"
    local notes_file="$2"
    local previous_tag
    local notes

    previous_tag="$(git -C "$REPO_ROOT" tag -l 'vice-mac-*' --sort=-creatordate | grep -v "^$tag$" | head -1 || true)"

    if [[ -n "$previous_tag" ]]; then
        notes="$(git -C "$REPO_ROOT" log "$previous_tag..HEAD" --pretty=format:"- %s" --no-merges)"
    else
        notes="$(git -C "$REPO_ROOT" log --pretty=format:"- %s" --no-merges -20)"
    fi

    if [[ -z "$notes" ]]; then
        notes="- No changes since the previous VICE Mac release."
    fi

    cat > "$notes_file" <<EOF
Apple Silicon macOS builds of the native VICE Mac apps.

Artifacts:
- DMG installer image
- SHA256 checksums
- Sparkle appcast

Changes:
$notes
EOF
}

write_appcast() {
    local tag="$1"
    local release_label="$2"
    local notes_file="$3"
    local dmg_path="$4"
    local appcast_file="$5"
    local repo
    local dmg_name
    local release_page_url
    local download_url
    local appcast_title
    local appcast_link
    local appcast_feed
    local download_url_xml
    local release_notes_cdata
    local signing_attrs
    local ed_signature
    local update_length
    local bundle_version
    local bundle_short_version
    local minimum_version
    local pub_date
    local sign_update

    repo="$(release_repo)"
    dmg_name="$(basename "$dmg_path")"
    release_page_url="https://github.com/$repo/releases/tag/$tag"
    download_url="https://github.com/$repo/releases/download/$tag/$dmg_name"
    appcast_title="$(printf 'VICE Mac %s' "$release_label" | xml_escape)"
    appcast_link="$(printf '%s' "$release_page_url" | xml_escape)"
    appcast_feed="$(printf '%s' "$SPARKLE_FEED_URL" | xml_escape)"
    download_url_xml="$(printf '%s' "$download_url" | xml_escape)"
    release_notes_cdata="$(cdata_escape < "$notes_file")"
    sign_update="$(find_sparkle_sign_update)"
    signing_attrs="$(sign_sparkle_artifact "$dmg_path" "$sign_update")"
    ed_signature="$(printf '%s\n' "$signing_attrs" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
    update_length="$(printf '%s\n' "$signing_attrs" | sed -n 's/.*length="\([0-9][0-9]*\)".*/\1/p')"
    bundle_version="$(release_bundle_version)"
    bundle_short_version="$(printf '%s' "$release_label" | xml_escape)"
    minimum_version="$(minimum_system_version)"
    pub_date="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

    if [[ -z "$ed_signature" || -z "$update_length" ]]; then
        echo "Sparkle signing output was not parseable: $signing_attrs" >&2
        exit 1
    fi

    cat > "$appcast_file" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>VICE Mac Updates</title>
        <description>Apple Silicon macOS builds of the native VICE Mac apps.</description>
        <language>en</language>
        <link>$appcast_feed</link>
        <item>
            <title>$appcast_title</title>
            <link>$appcast_link</link>
            <sparkle:version>$bundle_version</sparkle:version>
            <sparkle:shortVersionString>$bundle_short_version</sparkle:shortVersionString>
            <pubDate>$pub_date</pubDate>
            <description><![CDATA[$release_notes_cdata]]></description>
            <enclosure url="$download_url_xml" sparkle:edSignature="$ed_signature" length="$update_length" type="application/x-apple-diskimage" />
EOF

    if [[ -n "$minimum_version" ]]; then
        printf '            <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>\n' "$minimum_version" >> "$appcast_file"
    fi

    cat >> "$appcast_file" <<EOF
        </item>
    </channel>
</rss>
EOF
}

require_tool gh "Install GitHub CLI with: brew install gh"
require_tool plutil "plutil ships with macOS."

git -C "$REPO_ROOT" fetch --tags origin >/dev/null 2>&1 || git -C "$REPO_ROOT" fetch --tags >/dev/null 2>&1 || true

if [[ ! -d "$DIST_DIR" ]]; then
    echo "Release artifacts are missing at $DIST_DIR." >&2
    exit 1
fi

shopt -s nullglob
dmg_artifacts=("$DIST_DIR"/*.dmg)
if [[ "${#dmg_artifacts[@]}" -eq 0 ]]; then
    echo "No release artifacts found in $DIST_DIR." >&2
    exit 1
fi
if [[ "${#dmg_artifacts[@]}" -ne 1 ]]; then
    echo "Expected exactly one release DMG in $DIST_DIR, found ${#dmg_artifacts[@]}." >&2
    exit 1
fi

tag="$(release_tag)"
if [[ "$tag" != vice-mac-* ]]; then
    echo "VICE Mac release tags must start with 'vice-mac-'." >&2
    echo "Refusing to publish release for tag '$tag'." >&2
    exit 1
fi

release_label="${tag#vice-mac-}"
notes_file="$DIST_DIR/release-notes.md"
appcast_file="$DIST_DIR/appcast.xml"
repo_args=()
target_args=()

while IFS= read -r arg; do
    repo_args+=("$arg")
done < <(github_repo_args)

while IFS= read -r arg; do
    target_args+=("$arg")
done < <(release_target_args)

write_release_notes "$tag" "$notes_file"
write_appcast "$tag" "$release_label" "$notes_file" "${dmg_artifacts[0]}" "$appcast_file"

artifacts=("${dmg_artifacts[@]}")
if [[ -f "$DIST_DIR/SHA256SUMS.txt" ]]; then
    artifacts+=("$DIST_DIR/SHA256SUMS.txt")
fi
artifacts+=("$appcast_file")

if ! gh release view "$tag" "${repo_args[@]}" >/dev/null 2>&1; then
    gh release create "$tag" "${repo_args[@]}" "${target_args[@]}" \
        --title "VICE Mac $release_label" \
        --notes-file "$notes_file" \
        --draft
fi

gh release upload "$tag" "${repo_args[@]}" --clobber "${artifacts[@]}"
gh release edit "$tag" "${repo_args[@]}" \
    --title "VICE Mac $release_label" \
    --notes-file "$notes_file" \
    --draft=false \
    --prerelease=false \
    --latest

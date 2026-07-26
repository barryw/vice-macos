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

fetch_release_note_refs() {
    git -C "$REPO_ROOT" fetch --tags origin >/dev/null 2>&1 ||
        git -C "$REPO_ROOT" fetch --tags >/dev/null 2>&1 ||
        true

    # NOTE: no upstream fetch. Commits are classified as upstream VICE against
    # the pinned release commit (see release_note_upstream_ref).
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

html_escape() {
    xml_escape
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
    write_release_notes_file "$1" "$2" markdown
}

write_appcast_release_notes() {
    write_release_notes_file "$1" "$2" html
}

write_release_notes_file() {
    local tag="$1"
    local notes_file="$2"
    local format="$3"
    local release_label="${tag#vice-mac-}"
    local release_ref
    local release_commit
    local previous_tag
    local notes_dir
    local rev_args
    local commit
    local subject
    local category
    local category_file
    local source_label
    local commit_count=0
    local scan_limit="${VICE_MAC_RELEASE_NOTE_SCAN_LIMIT:-500}"

    release_ref="$(release_note_ref "$tag")"
    release_commit="$(git -C "$REPO_ROOT" rev-parse "$release_ref^{commit}")"
    previous_tag="$(git -C "$REPO_ROOT" describe --tags --match 'vice-mac-*' --abbrev=0 "$release_commit^" 2>/dev/null || true)"
    notes_dir="$(mktemp -d "${TMPDIR:-/tmp}/vicemac-notes.XXXXXX")"

    if [[ -n "$previous_tag" ]]; then
        rev_args=("$previous_tag..$release_ref")
    else
        rev_args=("$release_ref")
    fi

    while IFS= read -r commit; do
        if ! release_note_is_relevant_commit "$commit"; then
            continue
        fi

        subject="$(git -C "$REPO_ROOT" show -s --format=%s "$commit")"
        category="$(release_note_category "$subject")"
        category_file="$notes_dir/$category.tsv"
        source_label="$(release_note_source_label "$commit")"

        printf '%s\t%s\n' "$source_label" "$subject" >> "$category_file"
        commit_count=$((commit_count + 1))
        if [[ "$commit_count" -ge 20 ]]; then
            break
        fi
    done < <(git -C "$REPO_ROOT" rev-list --no-merges --max-count="$scan_limit" "${rev_args[@]}")

    if [[ "$commit_count" -eq 0 ]]; then
        printf 'LOCAL\tNo emulator-facing changes since the previous VICE Mac release.\n' >> "$notes_dir/changed.tsv"
    fi

    case "$format" in
        html)
            write_release_notes_html "$release_label" "$notes_dir" > "$notes_file"
            ;;
        markdown)
            write_release_notes_markdown "$release_label" "$notes_dir" > "$notes_file"
            ;;
        *)
            echo "Unknown release notes format: $format" >&2
            exit 1
            ;;
    esac

    rm -rf "$notes_dir"
}

release_note_is_relevant_commit() {
    local commit="$1"
    local path

    if release_note_is_upstream_commit "$commit"; then
        return 0
    fi

    while IFS= read -r path; do
        if release_note_is_machine_path "$path"; then
            return 0
        fi
    done < <(git -C "$REPO_ROOT" diff-tree --no-commit-id --name-only -r "$commit")

    return 1
}

release_note_is_machine_path() {
    local path="$1"

    case "$path" in
        macos/ViceMac/*|macos/ViceMac.xcodeproj/*|commodore-utils/*|vice/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

release_note_ref() {
    local tag="$1"

    if git -C "$REPO_ROOT" rev-parse --verify "$tag^{commit}" >/dev/null 2>&1; then
        echo "$tag"
        return
    fi

    if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
        echo "$CI_COMMIT_SHA"
        return
    fi

    echo "HEAD"
}

release_note_category() {
    local subject="$1"
    local lower

    lower="$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')"

    case "$lower" in
        deprecate*|deprecated*|remove*|removed*|drop*|dropped*|retire*|retired*)
            echo "deprecated"
            ;;
        fix*|fixed*|repair*|repaired*|correct*|corrected*|restore*|restored*|normalize*|normalized*|*crash*|*error*|*failure*|*failed*|*sign*|*notar*|*smoke*|*version*)
            echo "fixed"
            ;;
        add*|added*|introduce*|introduced*|implement*|implemented*|support*|supported*|enable*|enabled*|bundle*|bundled*|ship*|shipped*|publish*|published*|wire*|wired*)
            echo "new"
            ;;
        *)
            echo "changed"
            ;;
    esac
}

release_note_source_label() {
    local commit="$1"

    if release_note_is_upstream_commit "$commit"; then
        printf 'VICE'
    else
        printf 'LOCAL'
    fi
}

release_note_is_upstream_commit() {
    local commit="$1"
    local upstream_ref

    upstream_ref="$(release_note_upstream_ref)"
    if [[ -z "$upstream_ref" ]]; then
        return 1
    fi

    git -C "$REPO_ROOT" merge-base --is-ancestor "$commit" "$upstream_ref" >/dev/null 2>&1
}

# vice/ is pinned to an upstream VICE release; a commit counts as "upstream
# VICE" when it is an ancestor of that pinned release commit.
release_note_upstream_ref() {
    local pinned_commit

    if [[ -n "${VICE_MAC_UPSTREAM_REF:-}" ]]; then
        if git -C "$REPO_ROOT" rev-parse --verify "$VICE_MAC_UPSTREAM_REF^{commit}" >/dev/null 2>&1; then
            echo "$VICE_MAC_UPSTREAM_REF"
        fi
        return
    fi

    if [[ ! -f "$REPO_ROOT/VICE_UPSTREAM_RELEASE" ]]; then
        return
    fi

    pinned_commit="$(
        # shellcheck source=/dev/null
        . "$REPO_ROOT/VICE_UPSTREAM_RELEASE"
        printf '%s\n' "${VICE_UPSTREAM_RELEASE_COMMIT:-}"
    )"

    if [[ -n "$pinned_commit" ]] &&
        git -C "$REPO_ROOT" rev-parse --verify "$pinned_commit^{commit}" >/dev/null 2>&1; then
        echo "$pinned_commit"
    fi
}

markdown_escape() {
    sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g'
}

write_release_notes_markdown() {
    local release_label="$1"
    local notes_dir="$2"

    cat <<EOF
## VICE Mac $release_label

Native Apple Silicon VICE Mac release with signed DMG delivery, Sparkle updates, and targeted front-end or upstream emulator fixes.

EOF
    release_note_markdown_section "$notes_dir/new.tsv" "New"
    release_note_markdown_section "$notes_dir/changed.tsv" "Changed"
    release_note_markdown_section "$notes_dir/fixed.tsv" "Fixed"
    release_note_markdown_section "$notes_dir/deprecated.tsv" "Deprecated"
    cat <<EOF
### Package
- Notarized Apple Silicon DMG
- MacVICEKit SDK zip
- SHA256 checksums
- Sparkle appcast

Entries marked _upstream VICE_ come from the upstream VICE tree.
EOF
}

release_note_markdown_section() {
    local section_file="$1"
    local label="$2"
    local source_label
    local subject

    if [[ ! -s "$section_file" ]]; then
        return
    fi

    printf '### %s\n' "$label"
    while IFS=$'\t' read -r source_label subject; do
        if [[ "$source_label" == "VICE" ]]; then
            printf -- '- %s _upstream VICE_\n' "$(printf '%s' "$subject" | markdown_escape)"
        else
            printf -- '- %s\n' "$(printf '%s' "$subject" | markdown_escape)"
        fi
    done < "$section_file"
    printf '\n'
}

write_release_notes_html() {
    local release_label="$1"
    local notes_dir="$2"

    cat <<EOF
<div style="font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',Helvetica,Arial,sans-serif;line-height:1.36;color:#f4f4f4;">
    <p style="margin:0 0 14px 0;font-size:14px;color:#f4f4f4;">
        Focus: native Apple Silicon VICE Mac $release_label with signed DMG delivery, Sparkle updates, and targeted front-end or upstream emulator fixes.
    </p>
$(release_note_section "$notes_dir/new.tsv" "NEW" "#102d1b" "#48d17b")
$(release_note_section "$notes_dir/changed.tsv" "CHANGED" "#102b3d" "#57c7ff")
$(release_note_section "$notes_dir/fixed.tsv" "FIXED" "#302409" "#ffcf5a")
$(release_note_section "$notes_dir/deprecated.tsv" "DEPRECATED" "#32151a" "#ff6b7a")
    <p style="margin:12px 0 0 0;color:#b8b8b8;font-size:12px;">
        Package: notarized Apple Silicon DMG, MacVICEKit SDK zip, SHA256 checksums, and Sparkle appcast. Bullets marked <span style="display:inline-block;padding:1px 5px;border-radius:5px;background:#263f77;color:#dce8ff;font-size:10px;font-weight:800;letter-spacing:0;">VICE</span> come from the upstream VICE tree.
    </p>
</div>
EOF
}

release_note_section() {
    local section_file="$1"
    local label="$2"
    local background="$3"
    local foreground="$4"
    local source_label
    local subject

    if [[ ! -s "$section_file" ]]; then
        return
    fi

    cat <<EOF
    <div style="margin:0 0 12px 0;">
        <div style="margin:0 0 5px 0;">
            <span style="display:inline-block;border-radius:999px;background:$background;color:$foreground;border:1px solid $foreground;padding:2px 8px;font-size:11px;font-weight:800;letter-spacing:0;">$label</span>
        </div>
        <ul style="margin:0 0 0 18px;padding:0;color:#f4f4f4;">
$(while IFS=$'\t' read -r source_label subject; do
    if [[ "$source_label" == "VICE" ]]; then
        printf '            <li>%s%s</li>\n' "$(printf '%s' "$subject" | html_escape)" "$(release_note_source_badge_for_label "$source_label")"
    else
        printf '            <li>%s</li>\n' "$(printf '%s' "$subject" | html_escape)"
    fi
done < "$section_file")
        </ul>
    </div>
EOF
}

release_note_source_badge_for_label() {
    local source_label="$1"

    if [[ "$source_label" == "VICE" ]]; then
        printf ' <span title="Upstream VICE change" style="display:inline-block;margin-left:6px;padding:1px 5px;border-radius:5px;background:#263f77;color:#dce8ff;font-size:10px;font-weight:800;letter-spacing:0;vertical-align:1px;">VICE</span>'
    fi
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

publish_github_release_main() {
    require_tool gh "Install GitHub CLI with: brew install gh"
    require_tool plutil "plutil ships with macOS."

    fetch_release_note_refs

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
    appcast_notes_file="$DIST_DIR/appcast-release-notes.html"
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
    write_appcast_release_notes "$tag" "$appcast_notes_file"
    write_appcast "$tag" "$release_label" "$appcast_notes_file" "${dmg_artifacts[0]}" "$appcast_file"

    artifacts=("${dmg_artifacts[@]}")
    sdk_artifacts=("$DIST_DIR"/*.zip)
    if [[ "${#sdk_artifacts[@]}" -gt 0 ]]; then
        artifacts+=("${sdk_artifacts[@]}")
    fi
    if [[ -f "$DIST_DIR/SHA256SUMS.txt" ]]; then
        artifacts+=("$DIST_DIR/SHA256SUMS.txt")
    fi
    if [[ -f "$DIST_DIR/coverage.json" ]]; then
        artifacts+=("$DIST_DIR/coverage.json")
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
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    publish_github_release_main "$@"
fi

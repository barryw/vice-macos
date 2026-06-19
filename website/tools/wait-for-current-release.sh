#!/usr/bin/env bash
set -euo pipefail

if [[ "${VICE_MAC_WEBSITE_WAIT_FOR_RELEASE:-0}" != "1" ]]; then
    echo "GitHub release wait is disabled for this website run."
    exit 0
fi

REPO="${CI_REPO:-barryw/vice-macos}"
COMMIT_SHA="${CI_COMMIT_SHA:-}"
TIMEOUT_SECONDS="${VICE_MAC_WEBSITE_RELEASE_TIMEOUT_SECONDS:-7200}"
INTERVAL_SECONDS="${VICE_MAC_WEBSITE_RELEASE_INTERVAL_SECONDS:-30}"

if [[ -z "$COMMIT_SHA" ]]; then
    COMMIT_SHA="$(git rev-parse HEAD)"
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]]; then
    echo "Release wait timeout and interval must be numeric seconds." >&2
    exit 1
fi

if [[ "$INTERVAL_SECONDS" -lt 5 ]]; then
    INTERVAL_SECONDS=5
fi

started_at="$(date +%s)"
echo "Waiting for GitHub latest release in $REPO to point at $COMMIT_SHA."

while true; do
    status="$(
        REPO="$REPO" \
        COMMIT_SHA="$COMMIT_SHA" \
        GH_TOKEN="${GH_TOKEN:-}" \
        node <<'NODE'
const repo = process.env.REPO;
const commitSha = process.env.COMMIT_SHA;
const token = process.env.GH_TOKEN;
const shortSha = commitSha.slice(0, 7);

function isHexCommit(value) {
  return /^[0-9a-f]{7,40}$/i.test(value || "");
}

function matchesCommit(release) {
  const tagName = release.tag_name || "";
  const target = release.target_commitish || "";

  if (tagName.includes(shortSha)) {
    return true;
  }

  if (!isHexCommit(target)) {
    return false;
  }

  return target === commitSha || commitSha.startsWith(target) || target.startsWith(shortSha);
}

function hasRequiredAssets(release) {
  const assets = Array.isArray(release.assets) ? release.assets : [];
  const names = assets.map((asset) => asset.name || "");

  return {
    dmg: names.some((name) => /\.dmg$/i.test(name)),
    sdk: names.some((name) => /^MacVICEKit-(?!latest\b).+-arm64\.zip$/i.test(name)),
    checksums: names.some((name) => /^SHA256SUMS\.txt$/i.test(name)),
    appcast: names.some((name) => /^appcast\.xml$/i.test(name))
  };
}

async function requestLatestRelease() {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "vice-macos-website-release-wait"
  };

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  const response = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, { headers });
  if (!response.ok) {
    return {
      ready: false,
      message: `GitHub latest release lookup returned ${response.status}.`
    };
  }

  const release = await response.json();
  if (!matchesCommit(release)) {
    return {
      ready: false,
      message: `latest is ${release.tag_name || "unknown"}, not this commit yet.`
    };
  }

  const assets = hasRequiredAssets(release);
  const missing = Object.entries(assets)
    .filter(([, present]) => !present)
    .map(([name]) => name);

  if (missing.length > 0) {
    return {
      ready: false,
      message: `${release.tag_name} is latest but is missing ${missing.join(", ")}.`
    };
  }

  return {
    ready: true,
    message: `${release.tag_name} is latest and has the release assets.`
  };
}

requestLatestRelease()
  .then((result) => {
    console.log(`${result.ready ? "ready" : "waiting"}\t${result.message}`);
  })
  .catch((error) => {
    console.log(`waiting\t${error.message}`);
  });
NODE
    )"

    state="${status%%$'\t'*}"
    message="${status#*$'\t'}"

    if [[ "$state" == "ready" ]]; then
        echo "$message"
        exit 0
    fi

    now="$(date +%s)"
    elapsed=$((now - started_at))
    if [[ "$elapsed" -ge "$TIMEOUT_SECONDS" ]]; then
        echo "Timed out waiting for current GitHub release: $message" >&2
        exit 1
    fi

    echo "$message"
    sleep "$INTERVAL_SECONDS"
done

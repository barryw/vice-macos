(function () {
  const repo = "barryw/vice-macos";
  const latestReleaseUrl = `https://github.com/${repo}/releases/latest`;
  const apiUrl = `https://api.github.com/repos/${repo}/releases/latest`;

  const downloadLinks = [
    document.getElementById("hero-download"),
    document.getElementById("download-link")
  ].filter(Boolean);
  const releaseVersion = document.getElementById("release-version");
  const releaseAsset = document.getElementById("release-asset");
  const releasePublished = document.getElementById("release-published");
  const releaseNotesLink = document.getElementById("release-notes-link");
  const checksumsLink = document.getElementById("checksums-link");
  const heroReleaseNote = document.getElementById("hero-release-note");
  const kitSdkLinks = [
    document.getElementById("kit-sdk-download"),
    document.getElementById("kit-sdk-download-secondary")
  ].filter(Boolean);
  const kitSdkVersion = document.getElementById("kit-sdk-version");
  const kitSdkAsset = document.getElementById("kit-sdk-asset");
  const kitSdkNote = document.getElementById("kit-sdk-note");

  const formatDate = (value) => {
    if (!value) {
      return "";
    }

    return new Intl.DateTimeFormat(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric"
    }).format(new Date(value));
  };

  const formatBytes = (bytes) => {
    if (!Number.isFinite(bytes) || bytes <= 0) {
      return "";
    }

    const units = ["bytes", "KB", "MB", "GB"];
    let size = bytes;
    let unit = 0;

    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit += 1;
    }

    return `${size.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`;
  };

  fetch(apiUrl, {
    headers: {
      Accept: "application/vnd.github+json"
    }
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error(`GitHub release lookup failed: ${response.status}`);
      }

      return response.json();
    })
    .then((release) => {
      const assets = Array.isArray(release.assets) ? release.assets : [];
      const dmg = assets.find((asset) => /\.dmg$/i.test(asset.name));
      const kitSdk =
        assets.find((asset) => /^MacVICEKit-(?!latest\b).+-arm64\.zip$/i.test(asset.name)) ||
        assets.find((asset) => /^MacVICEKit-latest-arm64\.zip$/i.test(asset.name)) ||
        assets.find((asset) => /^MacVICEKit-.+\.zip$/i.test(asset.name));
      const checksums = assets.find((asset) => /sha256|checksum/i.test(asset.name));
      const date = formatDate(release.published_at);
      const version = release.tag_name || release.name || "latest release";

      if (releaseNotesLink && release.html_url) {
        releaseNotesLink.href = release.html_url;
      }

      if (checksumsLink && checksums) {
        checksumsLink.href = checksums.browser_download_url;
      }

      if (releaseVersion) {
        releaseVersion.textContent = version;
      }

      if (kitSdkVersion) {
        kitSdkVersion.textContent = version;
      }

      if (releasePublished && date) {
        releasePublished.textContent = `Published ${date}`;
      }

      if (dmg) {
        const size = formatBytes(dmg.size);
        const label = size ? `${dmg.name} - ${size}` : dmg.name;

        if (releaseAsset) {
          releaseAsset.textContent = label;
        }

        downloadLinks.forEach((link) => {
          link.href = dmg.browser_download_url;
          link.textContent = "Download latest DMG";
        });

        if (heroReleaseNote) {
          heroReleaseNote.textContent = `${version} is available as ${dmg.name}.`;
        }
      } else if (heroReleaseNote) {
        heroReleaseNote.textContent = `${version} is available on GitHub Releases.`;
      }

      if (kitSdk) {
        const size = formatBytes(kitSdk.size);
        const label = size ? `${kitSdk.name} - ${size}` : kitSdk.name;

        if (kitSdkAsset) {
          kitSdkAsset.textContent = label;
        }

        kitSdkLinks.forEach((link) => {
          link.href = kitSdk.browser_download_url;
          link.textContent = "Download SDK zip";
        });

        if (kitSdkNote) {
          kitSdkNote.textContent = `${version} includes ${kitSdk.name}.`;
        }
      } else if (kitSdkNote) {
        kitSdkNote.textContent = `${version} is available on GitHub Releases.`;
      }
    })
    .catch(() => {
      downloadLinks.forEach((link) => {
        link.href = latestReleaseUrl;
      });
      kitSdkLinks.forEach((link) => {
        link.href = latestReleaseUrl;
      });
    });
})();

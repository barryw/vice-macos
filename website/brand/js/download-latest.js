/*
 * Walker Heavy Industries — shared "Download latest" component.
 * Build & Release Standard §6 (docs/build-and-release-standard.md), WAL-39.
 *
 * ONE implementation, reused by every product site so the markup and styling
 * are identical. Progressive enhancement: the static <a> already points at
 * github.com/barryw/<repo>/releases/latest and works with no JS. This script
 * upgrades it to link the exact platform asset of the *current* GitHub Release
 * and to surface the version (tag_name).
 *
 * Markup contract (copy web/brand/templates/download-latest.html):
 *   <div class="whi-download" data-whi-download
 *        data-repo="barryw/vice-macos"   (required: owner/name)
 *        data-asset="dmg"                 (dmg | zip | tar | archive | page)
 *        data-match="..."                 (optional regex to pick the asset by name)
 *        data-platform="macOS"            (optional label shown in the meta line)
 *        data-product="VICE Mac">         (optional; defaults to the repo name)
 *     <a class="whi-btn whi-btn--line" data-whi-download-link
 *        href="https://github.com/barryw/vice-macos/releases/latest">
 *       <svg class="whi-icon" aria-hidden="true">
 *         <use href="brand/icons/icons.svg#whi-download"></use></svg>
 *       <span data-whi-download-label>Download latest</span>
 *     </a>
 *     <p class="whi-download__meta" data-whi-download-meta></p>
 *   </div>
 *
 * Private repos (FamiForge, NESBasic, RetroDraw, Novus): add `data-private`
 * (or data-asset="page"). The unauthenticated API can't read them, so we skip
 * the fetch and keep the static fallback link to the release/landing page.
 *
 * Dependency-free, no build step. Load once at the end of <body>:
 *   <script src="brand/js/download-latest.js" defer></script>
 */
(function () {
  "use strict";

  var API = "https://api.github.com/repos/";

  function $(root, sel) { return root.querySelector(sel); }

  // Human-readable byte size, e.g. 3.4 MB.
  function fmtSize(bytes) {
    if (!bytes && bytes !== 0) return "";
    var units = ["B", "KB", "MB", "GB"], i = 0, n = bytes;
    while (n >= 1024 && i < units.length - 1) { n /= 1024; i++; }
    return (i === 0 ? n : n.toFixed(1)) + " " + units[i];
  }

  // Month + year, e.g. "Jun 2026". Locale-independent fallback if Date parse fails.
  function fmtDate(iso) {
    if (!iso) return "";
    var d = new Date(iso);
    if (isNaN(d.getTime())) return "";
    var m = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
             "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return m[d.getUTCMonth()] + " " + d.getUTCFullYear();
  }

  // Choose the asset that matches the site's declared platform.
  function pickAsset(assets, opts) {
    if (!assets || !assets.length) return null;
    if (opts.match) {
      try {
        var re = new RegExp(opts.match, "i");
        var byRe = assets.filter(function (a) { return re.test(a.name); })[0];
        if (byRe) return byRe;
      } catch (e) { /* bad regex → fall through to asset-kind matching */ }
    }
    var ext = {
      dmg: /\.dmg$/i,
      zip: /\.zip$/i,
      tar: /\.(tar\.gz|tgz)$/i
    }[opts.asset];
    if (ext) {
      var byExt = assets.filter(function (a) { return ext.test(a.name); })[0];
      if (byExt) return byExt;
    }
    // archive / unknown / no match: first attached asset is the sensible default.
    return assets[0] || null;
  }

  function enhance(el) {
    var repo = el.getAttribute("data-repo");
    var link = $(el, "[data-whi-download-link]");
    if (!repo || !link) return;

    var labelEl = $(el, "[data-whi-download-label]");
    var metaEl = $(el, "[data-whi-download-meta]");
    var product = el.getAttribute("data-product") || repo.split("/").pop();
    var platform = el.getAttribute("data-platform") || "";

    // Private repos / page-only: keep the static fallback, no API call.
    if (el.hasAttribute("data-private") ||
        el.getAttribute("data-asset") === "page") {
      el.setAttribute("data-whi-download-state", "static");
      return;
    }

    var opts = {
      asset: el.getAttribute("data-asset") || "archive",
      match: el.getAttribute("data-match") || ""
    };

    el.setAttribute("data-whi-download-state", "loading");
    if (metaEl && !metaEl.textContent) metaEl.textContent = "Checking latest release…";

    fetch(API + repo + "/releases/latest", {
      headers: { "Accept": "application/vnd.github+json" }
    })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (rel) {
        var tag = rel.tag_name || "";
        var asset = pickAsset(rel.assets, opts);
        var href = (asset && asset.browser_download_url) ||
                   rel.html_url ||
                   link.getAttribute("href");

        link.setAttribute("href", href);
        if (labelEl && tag) labelEl.textContent = "Download " + product + " " + tag;

        if (metaEl) {
          var bits = [];
          if (platform) bits.push(platform);
          if (asset && asset.size) bits.push(fmtSize(asset.size));
          var when = fmtDate(rel.published_at);
          if (when) bits.push(when);
          metaEl.textContent = bits.join(" · ");
        }
        el.setAttribute("data-whi-download-state", "ready");
      })
      .catch(function () {
        // Rate-limited, offline, or repo not public yet: the static fallback
        // link still works — just clear the transient "checking…" text.
        if (metaEl && metaEl.textContent === "Checking latest release…") {
          metaEl.textContent = "";
        }
        el.setAttribute("data-whi-download-state", "fallback");
      });
  }

  function init() {
    var els = document.querySelectorAll("[data-whi-download]");
    for (var i = 0; i < els.length; i++) enhance(els[i]);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();

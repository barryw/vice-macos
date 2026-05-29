# mac VICE Website

Static marketing site for mac VICE.

Open `index.html` directly in a browser, or serve the `website/` directory from
any static host. There is no build step.

## Release Data

The main download button falls back to:

```text
https://github.com/barryw/vice-macos/releases/latest
```

At runtime, `site.js` asks the GitHub Releases API for the latest release and
updates the button to point at the current `.dmg` asset. It also updates the
version, publish date, and checksums link when that data is available.

That means the release pipeline can deploy this directory as-is after publishing
a new GitHub Release. If we later want a fully pinned, no-JavaScript release
page, the same pipeline can rewrite a small `release.json` or inject the latest
asset URL before upload.

## Screenshots

The screenshots in `assets/screenshots/` were captured from local debug builds
and resized for the web.
To refresh them after UI changes:

```sh
xcodebuild -project macos/ViceMac.xcodeproj -scheme "VICE Mac C64" -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/vice-macos-website-shots build
xcodebuild -project macos/ViceMac.xcodeproj -scheme "VICE Mac C128" -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/vice-macos-website-shots build
xcodebuild -project macos/ViceMac.xcodeproj -scheme "VICE Mac VIC-20" -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/vice-macos-website-shots build
xcodebuild -project macos/ViceMac.xcodeproj -scheme "VICE Mac PET" -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/vice-macos-website-shots build
xcodebuild -project macos/ViceMac.xcodeproj -scheme "VICE Mac Plus-4" -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/vice-macos-website-shots build
website/tools/capture-marketing-screenshots.sh
```

The capture script launches the built apps, boots the showcase disks used by the
gallery, opens the disk manager, writes raw captures to `/private/tmp`, and
updates the web-sized PNGs in `assets/screenshots/`.
macOS must allow the terminal app running the script to record the screen.

Pass `showcase` to refresh only the C64 HVSC and C128 GEOS gallery shots:

```sh
website/tools/capture-marketing-screenshots.sh showcase
```

The showcase capture looks for `HVSC_Intro_41.d64` or `20_Years_HVSC.d64`, and
for the GEOS 128 disks under `~/Downloads/geos128-v2/GEOS128-V2-Disks`. Override
those paths with:

```sh
VICE_MAC_SCREENSHOT_HVSC_DISK=/path/to/hvsc.d64 website/tools/capture-marketing-screenshots.sh showcase
VICE_MAC_SCREENSHOT_GEOS128_DISK=/path/to/geos128.d64 website/tools/capture-marketing-screenshots.sh showcase
```

For the Disk Image Manager screenshot, the script uses the first supported disk
image it finds in `~/Downloads`. Override that with:

```sh
VICE_MAC_SCREENSHOT_D64_LEFT=/path/to/disk.d64 website/tools/capture-marketing-screenshots.sh
```

Pass `disk-manager` to refresh only the disk manager captures. CP/M-formatted
D64s are real D64 containers, but they are not used for the marketing screenshot
until CP/M directory support lands in the manager.

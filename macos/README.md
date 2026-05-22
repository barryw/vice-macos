# VICE Mac

Native macOS frontend work for VICE. Each supported VICE machine has its own
macOS app target and shared Xcode scheme.

## Open In Xcode

Open `ViceMac.xcodeproj` from this directory.

## Command-Line Build

Command-line builds are the primary build path. Use one of the shared schemes:
`VICE Mac C64`, `VICE Mac VIC-20`, `VICE Mac PET`, `VICE Mac Plus-4`,
`VICE Mac C16`, `VICE Mac C232`, `VICE Mac V364`, or `VICE Mac C128`.

```sh
xcodebuild \
  -project macos/ViceMac.xcodeproj \
  -scheme "VICE Mac C64" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/vice-macos-derived-data \
  build
```

The app target is Apple Silicon first and sets `ARCHS = arm64`.

## Tests

Run the native macOS test suite with:

```sh
xcodebuild test \
  -project macos/ViceMac.xcodeproj \
  -scheme "VICE Mac Tests" \
  -configuration Debug \
  -derivedDataPath /private/tmp/vice-macos-tests \
  -destination 'platform=macOS'
```

## Release DMG

Build all release apps and package them into an installable Apple Silicon DMG:

```sh
macos/scripts/package-vicemac-release.sh
```

The DMG and `SHA256SUMS.txt` are written to `macos/dist`.

## Woodpecker CI

The root `.woodpecker.yml` expects a macOS Apple Silicon Woodpecker agent using
the local backend, with the latest Xcode selected and `dos2unix` installed. Tag
builds produce the release DMG and upload it to GitHub Releases with the
`github_token` secret available to the pipeline.

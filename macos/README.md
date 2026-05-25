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

The DMG and `SHA256SUMS.txt` are written to `macos/dist`. The release DMG
contains one app per machine: `x64sc.app`, `xvic.app`, `xpet.app`,
`xplus4.app`, `xc16.app`, `xc232.app`, `xv364.app`, and `x128.app`.
With current Xcode releases, install the separate Metal toolchain first:

```sh
xcodebuild -downloadComponent MetalToolchain
```

The package script auto-detects the installed Metal toolchain. Set
`VICE_MAC_XCODE_TOOLCHAIN` to override it, or
`VICE_MAC_AUTO_METAL_TOOLCHAIN=0` to use Xcode's default toolchain behavior.

For a signed and notarized release, provide a Developer ID Application identity
and notarytool credentials:

```sh
VICE_MAC_CODESIGN_IDENTITY="Developer ID Application: Example Name (TEAMID)" \
VICE_MAC_DEVELOPMENT_TEAM="TEAMID" \
VICE_MAC_NOTARYTOOL_PROFILE="vice-mac-notary" \
macos/scripts/package-vicemac-release.sh
```

Create the notarytool profile on the release machine with:

```sh
xcrun notarytool store-credentials vice-mac-notary \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD
```

When notarization is enabled, the script signs the apps and DMG, submits the
DMG to Apple, staples the ticket, validates it, and then writes checksums.
Set `VICE_MAC_NOTARIZE=0` to sign without notarizing, or use
`VICE_MAC_NOTARYTOOL_APPLE_ID`, `VICE_MAC_NOTARYTOOL_PASSWORD`, and
`VICE_MAC_NOTARYTOOL_TEAM_ID` instead of a stored profile.

## Woodpecker CI

The `.woodpecker/metal-ui.yaml` workflow runs on the `macos/native-metal`
branch and expects a macOS Apple Silicon Woodpecker agent using the local
backend, with the latest Xcode selected and `dos2unix` plus GitHub CLI `gh`
installed.
The prepare step downloads the Xcode Metal Toolchain component when it is not
already installed.

Push builds on `macos/native-metal` build, test, package, and publish a GitHub
Release named `vice-mac-<VICE version>-<git sha>-1`. Tags matching
`vice-mac-*` also package and publish a release for that tag. The pipeline
requires the `github_token` secret.

Notarized release builds also require `apple_codesign_identity` and
`apple_development_team`. CI uses `apple_notarytool_profile`, so the runner
keychain must already store that notarytool profile. For local runs outside CI,
the package script also supports `VICE_MAC_NOTARYTOOL_APPLE_ID`,
`VICE_MAC_NOTARYTOOL_PASSWORD`, and `VICE_MAC_NOTARYTOOL_TEAM_ID`.

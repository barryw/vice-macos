# VICE Mac

Native macOS frontend work for VICE. Each supported VICE machine has its own
macOS app target and shared Xcode scheme.

## Open In Xcode

Open `ViceMac.xcodeproj` from this directory.

## Command-Line Build

Command-line builds are the primary build path. Use one of the shared schemes:
`VICE Mac C64`, `VICE Mac VIC-20`, `VICE Mac PET`, `VICE Mac Plus-4`, or
`VICE Mac C128`.

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

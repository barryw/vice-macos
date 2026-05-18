# VICE Mac

Native macOS frontend work for VICE, starting with `x64sc`.

## Open In Xcode

Open `ViceMac.xcodeproj` from this directory.

## Command-Line Build

Command-line builds are the primary build path:

```sh
xcodebuild \
  -project macos/ViceMac.xcodeproj \
  -scheme ViceMac \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/vice-macos-derived-data \
  build
```

The app target is Apple Silicon first and sets `ARCHS = arm64`.

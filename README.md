# VICE Mac

Native Apple Silicon apps for VICE, built with SwiftUI and Metal.

This branch is the macOS-native front end for VICE. It keeps the real VICE
emulation core, but replaces the desktop experience with Mac apps that feel at
home on modern macOS: native windows, native menus, Metal video output,
first-class media handling, signed DMG releases, notarization, and Sparkle
updates through GitHub Releases.

## Download

Get the latest notarized DMG from:

https://github.com/barryw/vice-macos/releases/latest

The release package contains separate apps for each supported machine. Drag the
apps you want into `/Applications`.

## What Is Included

| App | Machine |
|---|---|
| `x64sc.app` | Commodore 64, cycle-exact |
| `xvic.app` | VIC-20 |
| `xpet.app` | PET |
| `xplus4.app` | Plus/4 |
| `xc16.app` | C16 |
| `xc232.app` | C232 |
| `xv364.app` | V364 |
| `x128.app` | C128 |
| `vsid.app` | SID player |

## Why This Exists

VICE is the emulator that serious Commodore users already trust. VICE Mac is
the Mac-native shell around that engine:

- No X11 or GTK runtime required for the Mac UI.
- One app per machine, with the traditional VICE executable names.
- Metal-rendered video with low-latency frame delivery from the emulator core.
- Native menus and toolbars for day-to-day emulator work.
- Apple Developer ID signing, notarization, stapled DMGs, and Sparkle updates.
- CI-built release artifacts with checksums and appcast metadata.

## Highlights

### Native Metal Display

The emulator frame buffer is rendered through Metal with display presets for a
clean LCD view, Commodore 1702/1084-style CRTs, PVM, RF, and green, amber, or
white phosphor displays. Scanlines, mask intensity, curvature, halation,
persistence, saturation, and warmth are all adjustable.

### Machine-Aware Controls

Each app boots with the right machine model, ROM slots, drive defaults, video
standard choices, SID options where supported, and machine-specific settings.
The UI exposes C64/C128/VIC-20/PET/Plus-4-family differences instead of forcing
everything through a generic emulator control panel.

### Media That Behaves Like Mac Media

Open and run PRG, T64, and TAP media. Attach disk images to the first compatible
drive, attach CRT cartridges on cartridge-capable machines, and load or save VSF
snapshots from standard macOS panels. Recent documents and drag/open behavior
work through normal AppKit paths.

### Disk Image Manager

VICE Mac includes a native disk image manager for Commodore block images:

- Open D64, D67, D71, D80, D81, and D82 images.
- Create blank disk images with a disk name and ID.
- Inspect directories, sectors, BAM allocation, and image geometry.
- Import PRG files, export files, rename files, and delete files.
- Clone optimized rebuilt images when the original image layout allows it.
- Package linked GEOS PRGs as GRC/CVT files and install them directly onto GEOS
  system disks.
- Patch GEOS input-driver ordering so a 1351 mouse can become the default
  driver without hand-editing disk sectors.
- Save modified images explicitly, so destructive edits stay under user control.

### GEOS And Tiny Commodore Utilities

This branch also carries a small `commodore-utils/` workspace for useful
machine-side tools that make the native Mac experience smoother. The first one
is `commodore-utils/geos-rtc`: a tiny GEOS auto-exec driver for C64 and C128
GEOS that reads VICE's DS1307 userport RTC and sets GEOS date/time during boot.

The disk image manager can validate the linked PRG, generate matching GEOS
metadata, export a CVT package, or install the auto-exec directly onto a GEOS
disk. With "Sync system time with machine" enabled, GEOS boots with the Mac's
current clock instead of the old default GEOS date.

Build the utility payloads with:

```sh
make -C commodore-utils/geos-rtc
```

### Controls, Sound, And Runtime State

Pause/resume, reset, speed, sound, volume, display mode, control ports, keyboard
joystick mapping, game controller mapping, drive reset, disk eject, true-drive
versus fast disk access, and paste-into-emulator are all available from native
controls.

### Optional AI Assistant

The app can expose an assistant panel backed by Apple Foundation Models on Macs
with Apple Intelligence available. It can answer questions about the current
machine or operate the emulator through the app's internal tool surface.

### MacVICEKit

The shared engine bridge, Metal display, audio/video sources, input forwarding,
media attachment, snapshots, and debugger APIs now live in `MacVICEKit/`. The
repo root keeps a tiny SwiftPM adapter manifest so Xcode users can add this repo
URL directly while the real package stays out of the website, k8s, and app
support files. The Mac apps dogfood that package so external tools can
eventually embed the same VICE runtime without copying app internals.

Release builds also publish `MacVICEKit-<version>-arm64.zip` and
`MacVICEKit-latest-arm64.zip`, which are self-contained Swift packages. The
package carries the Swift API, C bridge, matching signed
`MacVICERuntime.xcframework`, bundled runtime dependencies, VICEData, and a
manifest. See `MacVICEKit/README.md` and `docs/MacVICEKit.md` for consumer
setup and runtime layout.

## Updates

Sparkle is wired to the latest GitHub Release appcast:

```text
https://github.com/barryw/vice-macos/releases/latest/download/appcast.xml
```

Release DMGs are signed with the Sparkle EdDSA key, signed with a Developer ID
Application certificate, submitted to Apple notarization, stapled, smoke-tested,
and then published with checksums.

## Building

Open the Xcode project:

```sh
open macos/ViceMac.xcodeproj
```

Or build a machine from the command line:

```sh
xcodebuild \
  -project macos/ViceMac.xcodeproj \
  -scheme "VICE Mac C64" \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/vice-macos-derived-data \
  build
```

Run the native test suite:

```sh
xcodebuild test \
  -project macos/ViceMac.xcodeproj \
  -scheme "VICE Mac Tests" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/vice-macos-tests
```

Build the release DMG:

```sh
macos/scripts/package-vicemac-release.sh
```

Build only the reusable MacVICEKit SDK artifact:

```sh
macos/scripts/package-macvicekit-runtime.sh
```

Current Xcode releases require Apple's separate Metal toolchain component:

```sh
xcodebuild -downloadComponent MetalToolchain
```

The release script auto-detects the installed Metal toolchain. Set
`VICE_MAC_XCODE_TOOLCHAIN` to force a toolchain, or set
`VICE_MAC_AUTO_METAL_TOOLCHAIN=0` to use Xcode's default behavior.

## Signing And Notarization

For a local signed release:

```sh
VICE_MAC_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
VICE_MAC_DEVELOPMENT_TEAM="TEAMID" \
VICE_MAC_NOTARYTOOL_PROFILE="vice-mac-notary" \
macos/scripts/package-vicemac-release.sh
```

Create the notary profile once on the signing machine:

```sh
xcrun notarytool store-credentials vice-mac-notary \
  --apple-id you@example.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD
```

When notarization is enabled, the script signs all app bundles, re-signs
Sparkle's nested updater helpers, signs the DMG, submits it to Apple, staples
the ticket, validates the staple, and writes `SHA256SUMS.txt`.

## CI Release Flow

The Woodpecker `metal-ui` pipeline runs on pushes to `macos/native-metal` that
touch the native Mac app, VICE bridge, packaging, or MacVICEKit sources. Release
tags do not trigger a second release build.

On a green push, CI:

1. Prepares the VICE tree and Metal toolchain.
2. Builds and tests the native Mac apps.
3. Packages all machine apps into one Apple Silicon DMG.
4. Builds the reusable MacVICEKit SDK artifact with `MacVICERuntime.xcframework`.
5. Signs, notarizes, staples, and smoke-tests the DMG.
6. Publishes a GitHub Release named `vice-mac-<VICE version>-<git sha>-1`.
7. Uploads the DMG, MacVICEKit SDK zip, `SHA256SUMS.txt`, and `appcast.xml`.

Required Woodpecker secrets:

- `github_token`
- `sparkle_private_key`
- `apple_codesign_identity`
- `apple_development_team`
- `apple_notarytool_profile`

## Upstream VICE

This work builds on VICE, the canonical multi-platform Commodore emulator:

https://vice-emu.sourceforge.io/

The goal of this branch is not to fork the emulation core. The goal is to make
VICE feel excellent on macOS while staying close enough to upstream that the
engine work remains portable.

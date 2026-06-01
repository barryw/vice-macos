# MacVICEKit

MacVICEKit is the embeddable Swift package for native Mac VICE integrations. It exposes the shared engine bridge, Metal display view, audio and video frame sources, input forwarding, media attachment, snapshots, and monitor/debugger APIs without requiring a consumer app to understand the MacVICE app shell.

This package is dogfooded by the MacVICE app. Treat the API as internal while the app settles on the package surface; the runtime artifact is built and published with MacVICE releases.

## Add The Package

In Xcode, choose **File > Add Package Dependencies...** and add this repository URL. Select the `MacVICEKit` product.

The package implementation lives in `MacVICEKit/`. The repository root has a
small SwiftPM adapter manifest so package consumers can add the repo URL
directly, while local development can also open `MacVICEKit/Package.swift`
independently in Xcode.

The package builds the Swift and C bridge code. It does not build the VICE engine from source during package resolution. Consumer apps should use one of these runtime locations:

- `MacVICERuntimeLocation.frameworkBundle(...)` for a bundled `MacVICERuntime.framework`.
- `MacVICERuntimeLocation.directory(...)` for a prepared runtime directory containing `libvicemac*.dylib` files and `VICEData`.
- `MacVICERuntimeLocation.automatic`, which checks `MACVICE_RUNTIME_DIR`, then `com.barrywalker.MacVICERuntime`, then an embedded `MacVICERuntime.framework` in the app bundle, then the app bundle's direct Frameworks/VICEData layout, then a local source checkout runtime.

## Release SDK

Release builds produce `MacVICEKit-<version>-arm64.zip` alongside the signed
DMG. The archive contains:

- A SwiftPM package root with `Package.swift`.
- `MacVICEKit/` with the Swift API, C bridge, tests, and package README.
- `Runtime/MacVICERuntime.framework`.
- `Documentation/MacVICEKit.md`.

The runtime framework contains:

- `Frameworks/libvicemac*.dylib` for `x64sc`, `x128`, `xvic`, `xpet`, `xplus4`, and `vsid`.
- `Frameworks/*.dylib` for bundled non-system runtime dependencies.
- `Resources/VICEData` with the upstream VICE ROMs, keymaps, palettes, and data files.
- `Resources/MacVICERuntimeManifest.json` with the version, machine targets, architecture, and source SHAs.

Consumers can add the unzipped SDK folder as a local Swift package, embed
`Runtime/MacVICERuntime.framework` in their app's `Contents/Frameworks` folder,
and use `.automatic`; no hard-coded paths are needed.

The latest SDK is also uploaded with a stable asset name:

```text
https://github.com/barryw/vice-macos/releases/latest/download/MacVICEKit-latest-arm64.zip
```

Use the versioned asset for reproducible releases and the `latest` asset for local setup or quick consumer onboarding.

To build the SDK artifact locally:

```sh
macos/scripts/package-macvicekit-runtime.sh
```

The script builds the required native VICE dylibs unless
`VICE_MAC_RUNTIME_SKIP_BUILD=1` is set. It writes both
`MacVICEKit-<version>-arm64.zip` and `MacVICEKit-latest-arm64.zip`.

## Minimal Engine

```swift
import MacVICEKit

let configuration = MacVICEMachineConfiguration(
    machine: .c64sc,
    runtimeLocation: .automatic
)
let session = MacVICEEngineSession(configuration: configuration)

try session.start()
session.typeText("10 PRINT \"HELLO FROM MACVICEKIT\"\n20 GOTO 10\nRUN\n")
```

## SwiftUI Display

```swift
MacVICEDisplayView(session: session, configuration: .interactive)
    .frame(minWidth: 768, minHeight: 544)
```

For render-only previews, pass `.renderOnly` or provide your own `MacVICEVideoSource`.

For app-quality rendering, pass a `MacVICEDisplayConfiguration` with CRT filter settings, optional boot image URL, and mouse capture behavior:

```swift
let configuration = MacVICEDisplayConfiguration(
    preservesAspectRatio: true,
    filterSettings: .defaults(for: .commodore1702),
    forwardsInput: true,
    capturesMouse: true,
    bootImageURL: bootImageURL
)
```

Apps that need custom event routing can provide `MacVICEDisplayInputHandlers` instead of using `MacVICEEngineSession` as the input sink.

## Project Folder Drive

```swift
let projectURL = URL(fileURLWithPath: "/Users/me/C64Project", isDirectory: true)
let prgURL = projectURL.appendingPathComponent("build/demo.prg")

let configuration = MacVICEMachineConfiguration.c64(
    projectFolder: projectURL,
    autostart: prgURL,
    runtimeLocation: .automatic
)
```

That mounts the project folder as device 8 using VICE's filesystem device backend, with P00 conversion enabled and long filenames disabled on the emulated side.

## Debugger

```swift
let pc = try session.debugger.snapshot().programCounter
let bytes = try session.debugger.peek(address: 0x0801, length: 16)
let breakpointID = try session.debugger.setBreakpoint(address: pc)
try session.debugger.step()
try session.debugger.removeBreakpoint(id: breakpointID)
```

The public enums intentionally keep their raw values aligned with the C bridge ABI. The package test suite covers those values so IDE integrations get stable monitor/debugger behavior.

## Supported Machines

`MacVICEMachine` covers `x64sc`, `x128`, `xvic`, `xpet`, `xplus4`, `xc16`, `xc232`, `xv364`, and `vsid`. The TED-family variants use the `xplus4` dylib with the correct default VICE model argument.

# MacVICEKit

MacVICEKit is the embeddable Swift package behind MacVICE. It gives macOS apps a native Swift API for running VICE machines, rendering their display with Metal, forwarding Mac input, capturing screenshots, attaching media, and using monitor/debugger features without building a full emulator UI from scratch.

Use it when you want VICE inside another Mac app: an IDE, a debugger, an education tool, a SID player, a project launcher, or any app that needs a real Commodore machine behind a Mac-native interface.

## What It Provides

- A Swift engine session for starting and controlling VICE machines.
- SwiftUI/AppKit display embedding through `MacVICEDisplayView`.
- Metal rendering with configurable CRT-style filters.
- Keyboard, paste, joystick, and mouse input routing.
- Disk, tape, cartridge, snapshot, and autostart helpers.
- Video frame, audio sample, drive status, cartridge status, VSID, and SID voice callbacks.
- Monitor/debugger APIs for memory peek/poke, disassembly, breakpoints, stepping, and register updates.

## Add The Package

In Xcode:

1. Choose **File > Add Package Dependencies...**
2. Add:
   ```text
   https://github.com/barryw/vice-macos
   ```
3. Choose a dependency rule:
   - Use the current MacVICEKit development branch while the API is settling.
   - Use an exact revision when pairing against a specific MacVICE release.
   - Use SemVer tags once MacVICEKit starts publishing stable package versions.
4. Select the `MacVICEKit` product.

MacVICEKit contains the Swift API and the small C bridge. It does not contain the native VICE runtime dylibs because those are release artifacts, not source-package dependencies.

## Add The Runtime

MacVICEKit does not build VICE during Swift Package resolution. Consumers need a prepared MacVICE runtime artifact containing:

- `libvicemac*.dylib` runtime libraries.
- Bundled runtime dependencies.
- `VICEData` with ROMs, keymaps, palettes, and VICE data files.

MacVICE publishes this as `MacVICERuntime.framework` in GitHub Release assets.

For the newest runtime, download:

```text
https://github.com/barryw/vice-macos/releases/latest/download/MacVICERuntime-latest-arm64.framework.zip
```

For reproducible builds, use the versioned release asset instead:

```text
MacVICERuntime-<version>-arm64.framework.zip
```

Unzip the archive, then embed `MacVICERuntime.framework` in your app:

1. Open your app target in Xcode.
2. Go to **General > Frameworks, Libraries, and Embedded Content**.
3. Add `MacVICERuntime.framework`.
4. Set it to **Embed & Sign**.
5. Use `runtimeLocation: .automatic` in your `MacVICEMachineConfiguration`.

Users should not need Homebrew, command-line VICE binaries, shell scripts, or local build tools.

## Quick Start

This assumes `MacVICERuntime.framework` is embedded in your app target or `MACVICE_RUNTIME_DIR` points at a prepared runtime directory.

```swift
import SwiftUI
import MacVICEKit

struct EmulatorView: View {
    @State private var session = MacVICEEngineSession(
        configuration: MacVICEMachineConfiguration(
            machine: .c64sc,
            runtimeLocation: .automatic
        )
    )
    @State private var didStart = false

    var body: some View {
        MacVICEDisplayView(session: session)
            .frame(minWidth: 768, minHeight: 544)
            .task {
                guard !didStart else {
                    return
                }
                didStart = true

                do {
                    try session.start()
                } catch {
                    assertionFailure(error.localizedDescription)
                    return
                }

                session.typeText("10 PRINT \"HELLO FROM MACVICEKIT\"\n20 GOTO 10\nRUN\n")
            }
    }
}
```

That code starts `x64sc`, renders the machine, and feeds a tiny BASIC program through VICE's keyboard buffer.

## Runtime Lookup

`.automatic` checks, in order:

1. `MACVICE_RUNTIME_DIR`
2. A loaded `com.barrywalker.MacVICERuntime` framework
3. `MacVICERuntime.framework` embedded in the app bundle
4. A direct app bundle `Frameworks` plus `VICEData` layout
5. A local MacVICE source checkout build

For IDEs and tools, the recommended distribution model is to embed `MacVICERuntime.framework` in the app bundle so users do not need Homebrew, VICE binaries, or shell setup.

If you need a custom runtime location during development, set:

```sh
export MACVICE_RUNTIME_DIR=/path/to/runtime
```

That directory must contain the `libvicemac*.dylib` files plus `VICEData`.

## Supported Machines

`MacVICEMachine` currently supports `x64sc`, `x128`, `xvic`, `xpet`, `xplus4`, `xc16`, `xc232`, `xv364`, and `vsid`.

## More Documentation

See [../docs/MacVICEKit.md](../docs/MacVICEKit.md) for runtime packaging details, display configuration, project folder drives, and debugger examples.

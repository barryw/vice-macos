# ``MacVICEKit``

Embed VICE machines in native macOS apps.

@Metadata {
    @Available(macOS, introduced: "13.0")
}

## Overview

MacVICEKit is the Swift package behind mac VICE. It wraps the native VICE core
with APIs for starting emulator sessions, embedding a Metal display, forwarding
Mac input, attaching media, observing emulator callbacks, and building debugger
or inspection tools.

Use the release SDK zip for app integrations. The SDK includes the Swift
package, the C bridge, and the matching `MacVICERuntime.xcframework` artifact.

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

## Runtime Packaging

MacVICEKit does not build VICE during Swift package resolution. Apps should use
the release SDK or provide a prepared runtime directory. With
``MacVICERuntimeLocation/automatic``, runtime lookup checks `MACVICE_RUNTIME_DIR`,
embedded framework layouts, app bundle `Frameworks`, and local mac VICE checkout
builds.

The runtime must contain the machine-specific `libvicemac*.dylib` files and the
VICE data directory with ROMs, keymaps, palettes, and other runtime resources.

## Session Flow

Create a ``MacVICEMachineConfiguration``, create a ``MacVICEEngineSession``, and
call ``MacVICEEngineSession/start()``. Once the machine is running, use the
session to pause, reset, type text, attach media, read resources, capture
screenshots, or reach the monitor debugger through ``MacVICEEngineSession/debugger``.

## Topics

### Starting a Machine

- ``MacVICEEngineSession``
- ``MacVICEEngineStartResult``
- ``MacVICEMachineConfiguration``
- ``MacVICEMachine``
- ``MacVICEVideoStandard``
- ``MacVICELaunchPlan``
- ``MacVICEError``

### Runtime Resolution

- ``MacVICERuntime``
- ``MacVICERuntimeLocation``

### Display and Video

- ``MacVICEDisplayView``
- ``MacVICEDisplayConfiguration``
- ``MacVICETextureFiltering``
- ``MacVICEVideoFilterSettings``
- ``MacVICEVideoFilterPreset``
- ``MacVICEVideoFrame``
- ``MacVICEFrameSource``
- ``MacVICEVideoSource``
- ``MacVICEDisplayProfile``
- ``MacVICEBootFrame``

### Input

- ``MacVICEInputSink``
- ``MacVICEDisplayInputHandlers``

### Media and Storage

- ``MacVICEMediaRunMode``
- ``MacVICEStorageKind``
- ``MacVICEDriveConfiguration``
- ``MacVICETapeCommand``
- ``MacVICEROMSet``
- ``MacVICEROMOverride``

### Callbacks

- ``MacVICEEngineCallbacks``
- ``MacVICEDriveStatus``
- ``MacVICECartridgeStatus``
- ``MacVICEVSIDState``
- ``MacVICESIDVoiceSamples``
- ``MacVICEAudioSamples``
- ``MacVICEAudioSampleSource``
- ``MacVICEAudioSource``

### Debugger

- ``MacVICEDebugger``
- ``MacVICEDebuggerSnapshot``
- ``MacVICEMemorySpace``
- ``MacVICERegister``
- ``MacVICEDisassemblyLine``
- ``MacVICECheckpoint``
- ``MacVICECheckpointOperation``

# Native VICE Bridge

The macOS app should treat VICE as the emulation engine, not as a UI process.
SwiftUI owns the application chrome, settings, commands, and document behavior.
Metal owns presentation and display effects. VICE owns CPU, VIC-II, CIA, SID,
drive, input, and timing.

## Boundary

The bridge should be a narrow C ABI that can be called from Swift:

- start and stop x64sc on a dedicated engine thread
- reset, pause, warp, and change machine resources
- submit keyboard, joystick, paste, and media events
- deliver video frames as immutable RGBA buffers
- deliver audio buffers separately once video is stable

The Swift side copies each delivered video frame into `EmulatorFrameSource`.
`EmulatorRenderer` uploads the newest frame to a Metal texture and then runs the
filter chain. The renderer does not know whether a frame came from boot artwork,
x64sc, or a future recording source.

## VICE Side

Do not patch GTK or SDL. Do not use screenshots as the display path.

The correct VICE-side shape is a dedicated macOS arch layer under
`vice/src/arch/macos` that implements the same frontend hooks GTK, SDL, and
headless implement today:

- `video_canvas_create`
- `video_canvas_refresh`
- `video_canvas_set_palette`
- `video_canvas_resize`
- `video_init` and `video_shutdown`
- UI status/update stubs that forward state into the Swift model over the bridge

`video_canvas_refresh` should render VICE's palettized draw buffer to RGBA using
VICE's existing renderer and call the bridge frame callback. Cursor blink then
falls out naturally because it is produced by the running C64 KERNAL and VIC-II
state, not by Swift.

## Mac App Side

The app remains native:

- SwiftUI scenes, toolbar, settings, commands, and menus
- AppKit only where macOS interop requires it, such as `MTKView`
- Metal texture upload and filter passes
- no GTK, no SDL window, no helper UI, no screenshot polling

The x64sc engine can initially run in-process on a dedicated thread. If we need
crash isolation later, the process boundary should be a macOS-native XPC helper,
not an ad hoc display stream bolted onto headless mode.

## Current Status

- `--enable-macosui` configures VICE with `src/arch/macos`.
- `x64sc` links for arm64 with the native macOS arch layer.
- `video_canvas_refresh` publishes RGBA frames through `vicemacbridge`.
- Swift `EmulatorFrameSource` can accept live frames and the Metal renderer can
  upload them into the existing filter pipeline.
- The embedded x64sc engine target starts `main_program` on a dedicated thread
  from the Swift app and registers the frame callback before emulation starts.
- CoreAudio is selected through VICE's own sound resources and driver path; the
  native runtime build fails if VICE does not configure `soundcoreaudio.o` with
  the CoreAudio, AudioToolbox, and AudioUnit frameworks.
- Settings writes are queued through `vicemacbridge` and applied by the macOS UI
  event pump on the emulator thread.
- The first machine setting exposed by SwiftUI is `SidModel` for 6581/8580
  selection; VICE owns the SID model implementation and reconfiguration.
- Drive settings are exposed as VICE resources for units 8-11, including drive
  type, attachment, per-drive sound enablement, and per-drive sound volume.
- Drive LED status is published by the native macOS `uistatusbar` hook so the
  Swift bottom bar can show VICE's real activity/error state.

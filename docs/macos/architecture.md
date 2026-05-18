# VICE macOS Architecture

This branch is for a native macOS frontend for VICE, starting with `x64sc`.

## Platform Target

- Target Apple Silicon first.
- Build `arm64` only for the initial product.
- Do not spend engineering time on Intel or Universal binaries unless that becomes an explicit project decision later.
- Prefer Apple Silicon development paths and tooling, including `/opt/homebrew` when Homebrew dependencies are needed.

## UI Layer

- Use SwiftUI as the application UI layer.
- Do not use UIKit or Catalyst.
- Use AppKit only for macOS-native interop that SwiftUI cannot express cleanly.
- Host Metal with `MTKView` through `NSViewRepresentable`.

## Rendering

- Use Metal for emulator video output.
- The first renderer should favor correctness and simple frame delivery over clever optimization.
- The first useful path is:

```text
VICE video_canvas_refresh
  -> video_canvas_render into a CPU BGRA/RGBA buffer
  -> upload to MTLTexture
  -> draw through MTKView
```

Later renderer work can add texture rings, shader effects, integer scaling, CRT treatment, and latency tuning.

## Engine Boundary

- Treat VICE as the emulation engine.
- Keep Swift behind a narrow C or Objective-C bridge.
- Do not let SwiftUI reach directly into broad VICE internals.
- Start with `x64sc` only, then expand machine support after the frontend boundary is proven.

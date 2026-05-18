import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var showingFilterPanel = false

    var body: some View {
        VStack(spacing: 0) {
            EmulatorMetalView(frameSource: emulator.frameSource,
                              filterSettings: emulator.filterSettings,
                              onKeyEvent: emulator.handleKeyEvent,
                              onFlagsChanged: emulator.handleFlagsChanged,
                              onFocusLost: emulator.releaseAllKeys)
                .background(Color.black)
                .aspectRatio(emulator.frameSource.aspectRatio, contentMode: .fit)
                .frame(minWidth: 768, minHeight: 544)

            Divider()

            HStack(spacing: 14) {
                Label("x64sc", systemImage: "cpu")
                StatusPill(text: emulator.videoStandard.rawValue)
                StatusPill(text: emulator.isPaused ? "Paused" : "READY")
                StatusPill(text: emulator.filterSettings.preset.rawValue)

                Spacer()

                DriveIndicator(unit: 8, active: false)
                Text(emulator.statusText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .frame(height: 36)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    emulator.togglePause()
                } label: {
                    Label(emulator.isPaused ? "Resume" : "Pause",
                          systemImage: emulator.isPaused ? "play.fill" : "pause.fill")
                }
                .help(emulator.isPaused ? "Resume x64sc" : "Pause x64sc")

                Button {
                    emulator.reset()
                } label: {
                    Label("Reset", systemImage: "restart")
                }
                .help("Reset x64sc")

                Picker("Video", selection: $emulator.videoStandard) {
                    ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                        Text(standard.rawValue).tag(standard)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 118)
                .help("Video standard")

                VideoFilterPresetPicker()
                    .frame(width: 190)
                    .help("Display filter preset")

                Button {
                    showingFilterPanel.toggle()
                } label: {
                    Label("Tune Display", systemImage: "slider.horizontal.3")
                }
                .help("Tune display filters")
                .popover(isPresented: $showingFilterPanel, arrowEdge: .bottom) {
                    VideoFilterToolbarPanel()
                        .environmentObject(emulator)
                }
            }
        }
        .onAppear {
            emulator.start()
        }
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

private struct DriveIndicator: View {
    let unit: Int
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
            Text("Drive \(unit)")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EmulatorSession())
}

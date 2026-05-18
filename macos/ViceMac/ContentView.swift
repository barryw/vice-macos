import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        VStack(spacing: 0) {
            EmulatorMetalView()
                .background(Color.black)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .frame(minWidth: 720, minHeight: 540)

            Divider()

            HStack(spacing: 14) {
                Label("x64sc", systemImage: "cpu")
                StatusPill(text: emulator.videoStandard.rawValue)
                StatusPill(text: emulator.isPaused ? "Paused" : "Ready")

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
            Button {
                emulator.togglePause()
            } label: {
                Label(emulator.isPaused ? "Resume" : "Pause",
                      systemImage: emulator.isPaused ? "play.fill" : "pause.fill")
            }

            Button {
                emulator.reset()
            } label: {
                Label("Reset", systemImage: "restart")
            }
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

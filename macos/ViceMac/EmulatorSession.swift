import Combine
import Foundation

@MainActor
final class EmulatorSession: ObservableObject {
    @Published var isPaused = false
    @Published var warpMode = false
    @Published var videoStandard: VideoStandard = .ntsc
    @Published var statusText = "Idle"

    enum VideoStandard: String, CaseIterable, Identifiable {
        case ntsc = "NTSC"
        case pal = "PAL"

        var id: String { rawValue }
    }

    func reset() {
        statusText = "Reset queued"
    }

    func togglePause() {
        isPaused.toggle()
        statusText = isPaused ? "Paused" : "Running"
    }
}

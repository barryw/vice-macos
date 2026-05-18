import SwiftUI

@main
struct ViceMacApp: App {
    @StateObject private var emulator = EmulatorSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emulator)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Reset x64sc") {
                    emulator.reset()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button(emulator.isPaused ? "Resume" : "Pause") {
                    emulator.togglePause()
                }
                .keyboardShortcut("p", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(emulator)
        }
    }
}

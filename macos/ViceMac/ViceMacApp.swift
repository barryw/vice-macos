import AppKit
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
                Button("Soft Reset x64sc") {
                    emulator.reset(kind: .soft)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Hard Reset x64sc") {
                    emulator.reset(kind: .hard)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Button(emulator.isPaused ? "Resume" : "Pause") {
                    emulator.togglePause()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button("Toggle Full Screen") {
                    WindowActions.toggleFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(emulator)
        }
    }
}

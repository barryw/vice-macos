import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct ViceMacApp: App {
    @StateObject private var emulator = EmulatorSession()
    @StateObject private var aiSettings = AIAssistantSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emulator)
                .environmentObject(aiSettings)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Media...") {
                    MediaOpenPanel.openMedia(for: emulator, autorun: false)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Open and Run Media...") {
                    MediaOpenPanel.openMedia(for: emulator, autorun: true)
                }
                .keyboardShortcut("o", modifiers: [.command, .option])
            }

            CommandMenu("Machine") {
                Button(emulator.isPaused ? "Resume" : "Pause") {
                    emulator.togglePause()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Divider()

                Button("Soft Reset") {
                    emulator.reset(kind: .soft)
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Hard Reset") {
                    emulator.reset(kind: .hard)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Picker("Speed", selection: $emulator.emulationSpeed) {
                    ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }

                if emulator.machine.capabilities.supportsVideoStandardSelection {
                    Picker("Video Standard", selection: $emulator.videoStandard) {
                        ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                }
            }

            CommandMenu("Media") {
                ForEach(emulator.driveConfigurations) { configuration in
                    Menu("Drive \(configuration.unit)") {
                        Button("Attach Disk...") {
                            MediaOpenPanel.openDisk(for: emulator,
                                                    unit: configuration.unit,
                                                    autorun: false)
                        }

                        Button("Attach and Run Disk...") {
                            MediaOpenPanel.openDisk(for: emulator,
                                                    unit: configuration.unit,
                                                    autorun: true)
                        }

                        Divider()

                        Picker("Access", selection: driveAccessModeBinding(for: configuration.unit)) {
                            ForEach(DriveAccessMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Button("Reset Drive") {
                            emulator.resetDrive(configuration.unit)
                        }
                    }
                    .disabled(!configuration.isAttached)
                }

                if emulator.machine.capabilities.supportsCartridges {
                    Divider()

                    Button(emulator.cartridgeStatus.isAttached ? "Replace Cartridge..." : "Attach Cartridge...") {
                        MediaOpenPanel.openCartridge(for: emulator)
                    }

                    Button("Detach Cartridge") {
                        emulator.detachCartridge()
                    }
                    .disabled(!emulator.cartridgeStatus.isAttached)
                }
            }

            CommandMenu("Display") {
                Picker("Size", selection: $emulator.displayMode) {
                    ForEach(EmulatorSession.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if emulator.machine.supportsDisplayOutputSelection {
                    Picker("Output", selection: $emulator.displayOutput) {
                        ForEach(emulator.machine.displayOutputs) { output in
                            Text(output.statusTitle).tag(output)
                        }
                    }
                }

                Picker("Filter", selection: filterPresetBinding) {
                    ForEach(VideoFilterPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }

                Divider()

                Button("Toggle Full Screen") {
                    WindowActions.toggleFullScreen()
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(emulator)
                .environmentObject(aiSettings)
        }
    }

    private func driveAccessModeBinding(for unit: Int) -> Binding<DriveAccessMode> {
        Binding {
            emulator.driveAccessMode(for: unit)
        } set: { accessMode in
            emulator.setDriveAccessMode(accessMode, for: unit)
        }
    }

    private var filterPresetBinding: Binding<VideoFilterPreset> {
        Binding {
            emulator.filterSettings.preset
        } set: { preset in
            emulator.applyFilterPreset(preset)
        }
    }
}

@MainActor
private enum MediaOpenPanel {
    static func openMedia(for emulator: EmulatorSession, autorun: Bool) {
        let extensions = EmulatorMediaFile.supportedFilenameExtensions(for: emulator.machine)
        let panel = openPanel(title: autorun ? "Open and Run Media" : "Open Media",
                              message: "Choose disk or cartridge media for \(emulator.machineDisplayName).",
                              prompt: autorun ? "Open and Run" : "Open",
                              filenameExtensions: extensions)

        guard panel.runModal() == .OK else {
            return
        }

        emulator.openMedia(urls: panel.urls, autorun: autorun)
    }

    static func openDisk(for emulator: EmulatorSession, unit: Int, autorun: Bool) {
        guard let configuration = emulator.driveConfigurations.first(where: { $0.unit == unit }) else {
            return
        }

        let extensions = configuration.driveType.supportedDiskImageTypes.map(\.rawValue)
        let panel = openPanel(title: "Attach Disk",
                              message: "Choose a \(configuration.driveType.supportedDiskImageDescription) image for drive \(unit).",
                              prompt: autorun ? "Attach and Run" : "Attach",
                              filenameExtensions: extensions)

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachDisk(to: unit, url: url, autorun: autorun)
    }

    static func openCartridge(for emulator: EmulatorSession) {
        let panel = openPanel(title: "Attach Cartridge",
                              message: "Choose a CRT cartridge image for \(emulator.machineDisplayName).",
                              prompt: "Attach",
                              filenameExtensions: CartridgeImageFileType.allCases.map(\.rawValue))

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachCartridge(url: url)
    }

    private static func openPanel(title: String,
                                  message: String,
                                  prompt: String,
                                  filenameExtensions: [String]) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = title.hasPrefix("Open")
        panel.allowedContentTypes = contentTypes(for: filenameExtensions)

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        return panel
    }

    private static func contentTypes(for filenameExtensions: [String]) -> [UTType] {
        let types = filenameExtensions.compactMap { fileExtension in
            UTType(filenameExtension: fileExtension)
        }

        return types.isEmpty ? [.data] : types
    }
}

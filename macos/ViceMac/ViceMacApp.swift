import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct ViceMacApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var emulator = EmulatorSession()
    @StateObject private var aiSettings = AIAssistantSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(emulator)
                .environmentObject(aiSettings)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About VICE Mac") {
                    openWindow(id: AboutWindow.id)
                }
            }

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

        Window("About VICE Mac", id: AboutWindow.id) {
            AboutVICEView()
                .environmentObject(emulator)
                .containerBackground(.clear, for: .window)
                .background(AboutWindowControlsConfigurator())
        }
        .defaultSize(width: AboutWindow.size.width, height: AboutWindow.size.height)
        .windowResizability(.contentSize)

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

private enum AboutWindow {
    static let id = "about-vice-mac"
    static let size = CGSize(width: 680, height: 486)
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

private struct AboutVICEView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        ZStack {
            AboutWindowBackdrop(machine: emulator.machine)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 24) {
                    AboutHeroMark(machine: emulator.machine)
                        .frame(width: 236, height: 176)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(AppMetadata.displayName)
                                .font(.system(size: 34, weight: .bold, design: .rounded))

                            Text("A native Mac home for the VICE engine.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        AboutMachineStrip(machineName: emulator.machineDisplayName,
                                          viceTarget: emulator.machine.shortName,
                                          version: AppMetadata.viceVersionLine)

                        Text("Metal video, Core Audio sound, SwiftUI controls, Finder-aware media, and the excellent VICE emulation core underneath.")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            AboutCapabilityChip(title: "Metal", systemImage: "sparkles.tv")
                            AboutCapabilityChip(title: "Core Audio", systemImage: "waveform")
                            AboutCapabilityChip(title: "SwiftUI", systemImage: "macwindow")
                            AboutCapabilityChip(title: "VICE", systemImage: "cpu")
                        }
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 18)

                Divider()
                    .overlay(.white.opacity(0.12))

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Powered by the VICE project")
                                .font(.system(size: 12, weight: .semibold))

                            Text("VICE is free software distributed under the GNU General Public License.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        AboutBuildMetadataStrip(metadata: AppMetadata.buildMetadata)
                    }

                    Spacer()

                    Button("VICE Project") {
                        AppMetadata.openVICEProject()
                    }

                    Button("Copy Info") {
                        AppMetadata.copyVersionSummary(machineName: emulator.machineDisplayName,
                                                       viceTarget: emulator.machine.shortName)
                    }

                    Button("Done") {
                        dismissWindow(id: AboutWindow.id)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 16)
            }
            .padding(28)
        }
        .frame(width: AboutWindow.size.width, height: AboutWindow.size.height)
        .foregroundStyle(.primary)
    }
}

private struct AboutWindowControlsConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            Self.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.configure(window: nsView.window)
        }
    }

    private static func configure(window: NSWindow?) {
        guard let window else {
            return
        }

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.styleMask.remove([.miniaturizable, .resizable])
    }
}

private struct AboutBuildMetadataStrip: View {
    let metadata: AppBuildMetadata

    var body: some View {
        HStack(spacing: 6) {
            AboutBuildMetadataToken(label: "VICE", value: metadata.viceUpstreamSHA)
            AboutBuildMetadataToken(label: "Mac", value: metadata.macSHA)
        }
        .help("Build identifiers for bug reports")
    }
}

private struct AboutBuildMetadataToken: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.16), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AboutWindowBackdrop: View {
    let machine: EmulatedMachine

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            LinearGradient(colors: [
                machine.aboutAccent.opacity(0.42),
                Color.black.opacity(0.12),
                Color.black.opacity(0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing)

            RadialGradient(colors: [
                machine.aboutAccent.opacity(0.34),
                .clear
            ],
            center: .topLeading,
            startRadius: 28,
            endRadius: 420)

            AboutScanlineField()
                .opacity(0.26)
                .blendMode(.softLight)
        }
        .ignoresSafeArea()
    }
}

private struct AboutHeroMark: View {
    let machine: EmulatedMachine

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(machine.aboutAccent.opacity(0.15))
                .frame(width: 250, height: 136)
                .offset(y: 20)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.black.opacity(0.54),
                        Color.black.opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
                )
                .frame(width: 232, height: 154)
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: machine.aboutAccent.opacity(0.38), radius: 32, y: 18)

            VStack(spacing: 9) {
                AboutCRTDisplay(machine: machine)
                    .frame(width: 202, height: 110)

                HStack(spacing: 4) {
                    ForEach(machine.aboutStripeColors.indices, id: \.self) { index in
                        Capsule()
                            .fill(machine.aboutStripeColors[index])
                            .frame(width: index == 0 ? 34 : 22, height: 6)
                    }
                }
            }
            .offset(y: 12)
        }
        .frame(width: 236, height: 176, alignment: .center)
    }
}

private struct AboutCRTDisplay: View {
    let machine: EmulatedMachine

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(red: 0.015, green: 0.018, blue: 0.020))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(machine.aboutAccent.opacity(0.82), lineWidth: 1.4)
                }

            VStack(alignment: .leading, spacing: 9) {
                Text("**** \(machine.aboutBootName) ****")
                    .font(.system(size: 11.2, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                Text("READY.")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))

                HStack(spacing: 0) {
                    AboutBlinkingCursor()
                    Spacer()
                }
            }
            .foregroundStyle(machine.aboutAccent)
            .shadow(color: machine.aboutAccent.opacity(0.8), radius: 6)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            AboutScanlineField()
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .opacity(0.42)
        }
    }
}

private struct AboutBlinkingCursor: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let visible = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0

            Rectangle()
                .fill(.primary)
                .frame(width: 12, height: 14)
                .opacity(visible ? 1 : 0.18)
                .animation(.easeInOut(duration: 0.12), value: visible)
        }
    }
}

private struct AboutScanlineField: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<80, id: \.self) { _ in
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

private struct AboutMachineStrip: View {
    let machineName: String
    let viceTarget: String
    let version: String

    var body: some View {
        HStack(spacing: 10) {
            AboutMetadataPill(title: machineName, systemImage: "desktopcomputer")
                .layoutPriority(3)
            AboutMetadataPill(title: viceTarget, systemImage: "terminal")
                .layoutPriority(2)
            AboutMetadataPill(title: version, systemImage: "number")
                .layoutPriority(1)
        }
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct AboutMetadataPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
                .fixedSize(horizontal: true, vertical: false)
        }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.10), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct AboutCapabilityChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .frame(width: 76, height: 58)
        .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct AppBuildMetadata {
    let macSHA: String
    let viceUpstreamSHA: String
}

private enum AppMetadata {
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "VICE Mac"
    }

    static var viceVersionLine: String {
        "VICE \(viceVersion)"
    }

    static var buildMetadata: AppBuildMetadata {
        AppBuildMetadata(macSHA: bundleString(for: "VICEMacGitSHA"),
                         viceUpstreamSHA: bundleString(for: "VICEUpstreamGitSHA"))
    }

    static func copyVersionSummary(machineName: String, viceTarget: String) {
        let metadata = buildMetadata
        let summary = """
        \(displayName)
        VICE \(viceVersion)
        Machine \(machineName) / \(viceTarget)
        VICE upstream \(metadata.viceUpstreamSHA)
        Mac frontend \(metadata.macSHA)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }

    static func openVICEProject() {
        guard let url = URL(string: "https://vice-emu.sourceforge.io/") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static var viceVersion: String {
        guard let version = ViceEngineGetVersion() else {
            return "engine"
        }

        return String(cString: version)
    }

    private static func bundleString(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return "unknown"
        }

        return value
    }
}

private extension EmulatedMachine {
    var aboutAccent: Color {
        switch family {
        case .c64:
            return Color(red: 0.22, green: 0.38, blue: 1.0)
        case .c128:
            return Color(red: 0.30, green: 0.86, blue: 0.28)
        case .vic20:
            return Color(red: 0.08, green: 0.86, blue: 0.86)
        case .pet:
            return Color(red: 0.58, green: 0.95, blue: 0.58)
        case .ted:
            return Color(red: 0.95, green: 0.28, blue: 0.88)
        }
    }

    var aboutStripeColors: [Color] {
        [
            Color(red: 0.39, green: 0.18, blue: 0.80),
            Color(red: 0.23, green: 0.45, blue: 0.95),
            Color(red: 0.17, green: 0.72, blue: 0.92),
            Color(red: 0.27, green: 0.82, blue: 0.44)
        ]
    }

    var aboutBootName: String {
        switch family {
        case .c64:
            return "COMMODORE 64"
        case .c128:
            return "COMMODORE 128"
        case .vic20:
            return "CBM BASIC V2"
        case .pet:
            return "COMMODORE PET"
        case .ted:
            return displayName.uppercased()
        }
    }
}

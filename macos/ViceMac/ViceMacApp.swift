import AppKit
import Darwin
import Sparkle
import SwiftUI
import UniformTypeIdentifiers

@main
struct ViceMacApp: App {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.diskImageManagerActions) private var diskImageManagerActions
    @NSApplicationDelegateAdaptor(ViceMacAppDelegate.self) private var appDelegate
    @StateObject private var emulator = EmulatorSession()
    @StateObject private var aiSettings = AIAssistantSettings()
    private let launchConfiguration: ViceMacLaunchConfiguration
    private let updaterController: SPUStandardUpdaterController

    init() {
        let launchConfiguration = ViceMacLaunchConfiguration.current
        self.launchConfiguration = launchConfiguration
        updaterController = SPUStandardUpdaterController(startingUpdater: launchConfiguration.releaseSmokeTest == nil,
                                                        updaterDelegate: nil,
                                                        userDriverDelegate: nil)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let smokeTestConfiguration = launchConfiguration.releaseSmokeTest {
                    ReleaseSmokeTestView(configuration: smokeTestConfiguration)
                } else {
                    ContentView()
                }
            }
                .environmentObject(emulator)
                .environmentObject(aiSettings)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About VICE Mac") {
                    openWindow(id: AboutWindow.id)
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
            }

            CommandGroup(replacing: .newItem) {
                if let diskImageManagerActions {
                    Button("New Disk Image...") {
                        diskImageManagerActions.createImage()
                    }
                    .keyboardShortcut("n", modifiers: [.command])

                    Button("Open Disk Image...") {
                        diskImageManagerActions.openImage()
                    }
                    .keyboardShortcut("o", modifiers: [.command])
                } else {
                    Button("Open Media...") {
                        MediaOpenPanel.openMedia(for: emulator, autorun: false)
                    }
                    .keyboardShortcut("o", modifiers: [.command])

                    Button("Open and Run Media...") {
                        MediaOpenPanel.openMedia(for: emulator, autorun: true)
                    }
                    .keyboardShortcut("o", modifiers: [.command, .option])

                    Button("Load Snapshot...") {
                        MediaOpenPanel.loadSnapshot(for: emulator)
                    }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                }
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    diskImageManagerActions?.saveActiveImage()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(diskImageManagerActions?.canSaveActiveImage != true)

                Button("Save Snapshot...") {
                    MediaOpenPanel.saveSnapshot(for: emulator)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
            }

            CommandGroup(after: .pasteboard) {
                Button("Paste into Emulator") {
                    emulator.pasteFromPasteboard()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(!emulator.canReceiveKeyboardText)
            }

            CommandMenu("Machine") {
                Button(emulator.isPaused ? "Resume" : "Pause") {
                    emulator.togglePause()
                }

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
                Button("Disk Image Manager...") {
                    openWindow(id: DiskImageManagerWindow.id)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                if let diskImageManagerActions {
                    Divider()

                    Button("Import PRG...") {
                        diskImageManagerActions.importProgram()
                    }
                    .disabled(!diskImageManagerActions.canImportProgram)

                    Button("Export Selected File...") {
                        diskImageManagerActions.exportSelectedFile()
                    }
                    .disabled(!diskImageManagerActions.canExportSelectedFile)

                    Button("Clone Optimized Image...") {
                        diskImageManagerActions.cloneOptimizedImage()
                    }
                    .disabled(!diskImageManagerActions.canCloneOptimizedImage)

                    Button("Rename Selected File...") {
                        diskImageManagerActions.renameSelectedFile()
                    }
                    .disabled(!diskImageManagerActions.canRenameSelectedFile)

                    Button("Delete Selected File") {
                        diskImageManagerActions.deleteSelectedFile()
                    }
                    .disabled(!diskImageManagerActions.canDeleteSelectedFile)
                }

                Divider()

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

                        if configuration.driveType.slotCount > 1 {
                            Menu("Detach Disk") {
                                ForEach(configuration.driveType.driveNumbers, id: \.self) { driveNumber in
                                    Button("Drive \(configuration.unit):\(driveNumber)") {
                                        emulator.detachDisk(from: configuration.unit,
                                                            driveNumber: driveNumber)
                                    }
                                    .disabled(!emulator.hasDiskAttached(to: configuration.unit,
                                                                        driveNumber: driveNumber))
                                }
                            }
                        } else {
                            Button("Detach Disk") {
                                emulator.detachDisk(from: configuration.unit)
                            }
                            .disabled(!emulator.hasDiskAttached(to: configuration.unit,
                                                                driveNumber: 0))
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
                        Label(preset.title, systemImage: preset.systemImage).tag(preset)
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

        Window("Disk Image Manager", id: DiskImageManagerWindow.id) {
            DiskImageManagerView()
        }
        .defaultSize(width: DiskImageManagerWindow.size.width,
                     height: DiskImageManagerWindow.size.height)

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
private final class ViceMacAppDelegate: NSObject, NSApplicationDelegate {
    private var smokeTestSession: EmulatorSession?
    private var didRequestEngineTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let configuration = ViceMacLaunchConfiguration.current.releaseSmokeTest else {
            return
        }

        NSApp.setActivationPolicy(.accessory)

        let emulator = EmulatorSession()
        smokeTestSession = emulator

        Task { @MainActor [emulator] in
            await ReleaseSmokeTestRunner.run(configuration: configuration, emulator: emulator)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        WindowFrameRestoration.saveOpenWindowFrames()

        guard ViceEngineIsRunning() else {
            return .terminateNow
        }

        guard !didRequestEngineTermination else {
            return .terminateLater
        }

        didRequestEngineTermination = true
        if !ViceEngineRequestQuit() {
            Darwin._exit(0)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            Darwin._exit(0)
        }

        return .terminateLater
    }
}

private struct ViceMacLaunchConfiguration {
    let releaseSmokeTest: ViceMacReleaseSmokeTestConfiguration?

    static var current: ViceMacLaunchConfiguration {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isSmokeTest = arguments.contains("--vice-mac-smoke-test")
            || environment["VICE_MAC_RELEASE_SMOKE_TEST"] == "1"

        guard isSmokeTest else {
            return ViceMacLaunchConfiguration(releaseSmokeTest: nil)
        }

        let timeout = value(after: "--vice-mac-smoke-timeout", in: arguments)
            .flatMap(TimeInterval.init)
            ?? environment["VICE_MAC_SMOKE_TIMEOUT"].flatMap(TimeInterval.init)
            ?? 35

        return ViceMacLaunchConfiguration(
            releaseSmokeTest: ViceMacReleaseSmokeTestConfiguration(timeout: max(1, timeout))
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }

        return arguments[index + 1]
    }
}

private struct ViceMacReleaseSmokeTestConfiguration {
    let timeout: TimeInterval
}

private struct ReleaseSmokeTestView: View {
    let configuration: ViceMacReleaseSmokeTestConfiguration

    var body: some View {
        Color.black
            .frame(width: 320, height: 240)
    }
}

private enum ReleaseSmokeTestRunner {
    @MainActor
    static func run(configuration: ViceMacReleaseSmokeTestConfiguration,
                    emulator: EmulatorSession) async {
        ReleaseSmokeTestProcess.print("VICE Mac release smoke test starting for \(emulator.machine.shortName)")
        emulator.start()

        let deadline = Date().addingTimeInterval(configuration.timeout)
        var lastSequence: UInt64 = 0
        var lastStatus = "no emulator frame received"

        while Date() < deadline {
            if let frame = emulator.frameSource.copyLatestFrame(after: lastSequence) {
                lastSequence = frame.sequence
                if let stats = ReleaseSmokeFrameAnalyzer.analyze(frame) {
                    lastStatus = stats.summary
                    if stats.passed {
                        ReleaseSmokeTestProcess.succeed(
                            "VICE Mac release smoke test passed for \(emulator.machine.shortName): \(stats.summary)"
                        )
                    }
                } else {
                    lastStatus = "invalid emulator frame"
                }
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let startupErrorMessage = emulator.startupError?.message ?? lastEngineErrorMessage()
        let startupError = startupErrorMessage.map {
            "; error=\($0.replacingOccurrences(of: "\n", with: " "))"
        } ?? ""

        ReleaseSmokeTestProcess.fail(
            "VICE Mac release smoke test failed for \(emulator.machine.shortName): \(lastStatus); status=\(emulator.statusText)\(startupError)"
        )
    }

    private static func lastEngineErrorMessage() -> String? {
        guard let error = ViceEngineGetLastError() else {
            return nil
        }

        let message = String(cString: error).trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }
}

private enum ReleaseSmokeTestProcess {
    static func print(_ message: String) {
        fputs(message + "\n", stdout)
        fflush(stdout)
    }

    static func succeed(_ message: String) -> Never {
        print(message)
        Darwin._exit(0)
    }

    static func fail(_ message: String) -> Never {
        fputs(message + "\n", stderr)
        fflush(stderr)
        Darwin._exit(2)
    }
}

private struct ReleaseSmokeFrameStats {
    let width: Int
    let height: Int
    let sequence: UInt64
    let samples: Int
    let averageLuma: Double
    let nonDarkRatio: Double
    let blueDominantRatio: Double
    let colorBucketCount: Int

    var passed: Bool {
        averageLuma >= 20.0
            && nonDarkRatio >= 0.20
            && (blueDominantRatio >= 0.08 || colorBucketCount >= 4)
    }

    var summary: String {
        String(
            format: "sequence=%llu size=%dx%d avgLuma=%.1f nonDark=%.3f blue=%.3f buckets=%d samples=%d",
            sequence,
            width,
            height,
            averageLuma,
            nonDarkRatio,
            blueDominantRatio,
            colorBucketCount,
            samples
        )
    }
}

private enum ReleaseSmokeFrameAnalyzer {
    static func analyze(_ frame: EmulatorVideoFrame) -> ReleaseSmokeFrameStats? {
        guard frame.width > 0,
              frame.height > 0,
              frame.bytesPerRow >= frame.width * 4,
              frame.pixels.count >= frame.bytesPerRow * frame.height else {
            return nil
        }

        let cropX0 = max(0, Int(Double(frame.width) * 0.12))
        let cropX1 = min(frame.width, Int(Double(frame.width) * 0.88))
        let cropY0 = max(0, Int(Double(frame.height) * 0.12))
        let cropY1 = min(frame.height, Int(Double(frame.height) * 0.88))
        let cropWidth = max(1, cropX1 - cropX0)
        let cropHeight = max(1, cropY1 - cropY0)
        let sampleStep = max(1, min(cropWidth / 180, cropHeight / 120))

        var sampleCount = 0
        var totalLuma = 0.0
        var nonDarkCount = 0
        var blueDominantCount = 0
        var colorBuckets = Set<Int>()

        frame.pixels.withUnsafeBytes { pixelBytes in
            guard let baseAddress = pixelBytes.baseAddress else {
                return
            }

            let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)
            var y = cropY0
            while y < cropY1 {
                var x = cropX0
                while x < cropX1 {
                    let offset = y * frame.bytesPerRow + x * 4
                    let r = Int(pixels[offset])
                    let g = Int(pixels[offset + 1])
                    let b = Int(pixels[offset + 2])
                    let luma = (0.2126 * Double(r)) + (0.7152 * Double(g)) + (0.0722 * Double(b))

                    sampleCount += 1
                    totalLuma += luma
                    if luma > 24.0 {
                        nonDarkCount += 1
                    }
                    if b >= 45 && b > r + 12 && b > g + 8 {
                        blueDominantCount += 1
                    }

                    let bucket = ((r / 32) << 6) | ((g / 32) << 3) | (b / 32)
                    colorBuckets.insert(bucket)
                    x += sampleStep
                }
                y += sampleStep
            }
        }

        guard sampleCount > 0 else {
            return nil
        }

        return ReleaseSmokeFrameStats(width: frame.width,
                                      height: frame.height,
                                      sequence: frame.sequence,
                                      samples: sampleCount,
                                      averageLuma: totalLuma / Double(sampleCount),
                                      nonDarkRatio: Double(nonDarkCount) / Double(sampleCount),
                                      blueDominantRatio: Double(blueDominantCount) / Double(sampleCount),
                                      colorBucketCount: colorBuckets.count)
    }
}

private enum AboutWindow {
    static let id = "about-vice-mac"
    static let size = CGSize(width: 680, height: 486)
}

private enum DiskImageManagerWindow {
    static let id = "disk-image-manager"
    static let size = CGSize(width: 1_180, height: 780)
}

@MainActor
private enum MediaOpenPanel {
    static func openMedia(for emulator: EmulatorSession, autorun: Bool) {
        let extensions = EmulatorMediaFile.supportedFilenameExtensions(for: emulator.machine)
        let panel = openPanel(title: autorun ? "Open and Run Media" : "Open Media",
                              message: "Choose media for \(emulator.machineDisplayName).",
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

    static func loadSnapshot(for emulator: EmulatorSession) {
        let panel = openPanel(title: "Load Snapshot",
                              message: "Choose a VICE snapshot for \(emulator.machineDisplayName).",
                              prompt: "Load",
                              filenameExtensions: SnapshotFileType.allCases.map(\.rawValue))

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.loadSnapshot(url: url)
    }

    static func saveSnapshot(for emulator: EmulatorSession) {
        let panel = NSSavePanel()
        panel.title = "Save Snapshot"
        panel.message = "Save the current \(emulator.machineDisplayName) machine state."
        panel.prompt = "Save"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(emulator.machine.shortName)-Snapshot.vsf"
        panel.allowedContentTypes = contentTypes(for: SnapshotFileType.allCases.map(\.rawValue))

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        let snapshotURL = SnapshotFileType(url: url) == nil
            ? url.appendingPathExtension(SnapshotFileType.vsf.rawValue)
            : url
        emulator.saveSnapshot(url: snapshotURL)
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

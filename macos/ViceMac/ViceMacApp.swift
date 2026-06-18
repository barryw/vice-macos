import AppKit
import Darwin
import MacVICEKit
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
    @StateObject private var aiDocumentLibrary = AIDocumentLibraryStore()
    @StateObject private var metadataSettings = MetadataIngestionSettings()
    @StateObject private var qLinkReloaded = QLinkReloadedService()
    #if VICE_MAC_APP_VSID
    @StateObject private var vsid = VSIDSession()
    #endif
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
        #if VICE_MAC_APP_VSID
        WindowGroup {
            VSIDPlayerView()
                .environmentObject(vsid)
                .containerBackground(.clear, for: .window)
        }
        .defaultSize(width: 1_040, height: 680)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About mac VICE VSID") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "mac VICE VSID",
                        .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                        .version: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                    ])
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
            }

            CommandGroup(replacing: .newItem) {
                Button("Open SID...") {
                    vsid.openSIDPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Playback") {
                Button(vsid.isPlaying ? "Pause" : "Play") {
                    vsid.isPlaying ? vsid.pause() : vsid.playOrResume()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Stop") {
                    vsid.stop()
                }
                .keyboardShortcut(".", modifiers: [.command])

                Divider()

                Button("Previous Tune") {
                    vsid.selectPreviousTune()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(!vsid.canSelectPreviousTune)

                Button("Next Tune") {
                    vsid.selectNextTune()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(!vsid.canSelectNextTune)
            }
        }
        #else
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
                .environmentObject(aiDocumentLibrary)
                .environmentObject(metadataSettings)
                .environmentObject(qLinkReloaded)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About mac VICE") {
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

                Button("Export Screenshot...") {
                    MediaOpenPanel.exportScreenshot(for: emulator)
                }
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
                Button("Media Library...") {
                    openWindow(id: MediaLibraryWindow.id)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Disk Image Manager...") {
                    openWindow(id: DiskImageManagerWindow.id)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Print Queue...") {
                    openWindow(id: PrintQueueWindow.id)
                    emulator.refreshPrintQueue()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                if let diskImageManagerActions {
                    Divider()

                    Button("Import File...") {
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
                        if configuration.storageKind == .sharedFolder {
                            Button("Reveal Shared Folder") {
                                revealSharedFolder(configuration)
                            }
                            .disabled(configuration.sharedFolderPath == nil)
                        } else if configuration.driveType.slotCount > 1 {
                            Menu("Attach Disk") {
                                ForEach(configuration.driveType.driveNumbers, id: \.self) { driveNumber in
                                    Button("Drive \(configuration.unit):\(driveNumber)...") {
                                        MediaOpenPanel.openDisk(for: emulator,
                                                                unit: configuration.unit,
                                                                driveNumber: driveNumber,
                                                                autorun: false)
                                    }
                                }
                            }

                            Menu("Attach and Run Disk") {
                                ForEach(configuration.driveType.driveNumbers, id: \.self) { driveNumber in
                                    Button("Drive \(configuration.unit):\(driveNumber)...") {
                                        MediaOpenPanel.openDisk(for: emulator,
                                                                unit: configuration.unit,
                                                                driveNumber: driveNumber,
                                                                autorun: true)
                                    }
                                }
                            }
                        } else {
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
                        }

                        if configuration.storageKind != .sharedFolder {
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
                        }

                        Divider()

                        if configuration.storageKind != .sharedFolder {
                            Picker("Access", selection: driveAccessModeBinding(for: configuration.unit)) {
                                ForEach(DriveAccessMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
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

            CommandMenu("Online") {
                Button("Connect to Q-Link Reloaded") {
                    qLinkReloaded.connect(emulator: emulator)
                }
                .keyboardShortcut("q", modifiers: [.command, .shift])
                .disabled(!qLinkReloaded.canConnect(machine: emulator.machine))

                Button("Choose Q-Link Disk...") {
                    qLinkReloaded.chooseDisk(for: emulator.machine)
                }
                .disabled(!qLinkReloaded.supports(machine: emulator.machine) || qLinkReloaded.isConnecting)

                Button("Forget Q-Link Disk") {
                    qLinkReloaded.forgetDisk()
                }
                .disabled(!qLinkReloaded.hasConfiguredDisk || qLinkReloaded.isConnecting)
            }

            CommandMenu("Debug") {
                Button("Debugger...") {
                    openWindow(id: DebuggerWindow.id)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])

                Divider()

                Button(emulator.isPaused ? "Resume" : "Pause") {
                    emulator.togglePause()
                }

                Button("Step") {
                    try? emulator.engine.debugger.step(count: 1, over: false)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!emulator.isMachineRunning)
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

        Window("About mac VICE", id: AboutWindow.id) {
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

        Window("Media Library", id: MediaLibraryWindow.id) {
            MediaLibraryView()
                .environmentObject(emulator)
                .environmentObject(metadataSettings)
        }
        .defaultSize(width: MediaLibraryWindow.size.width,
                     height: MediaLibraryWindow.size.height)

        Window("Debugger", id: DebuggerWindow.id) {
            DebuggerView()
                .environmentObject(emulator)
        }
        .defaultSize(width: DebuggerWindow.size.width,
                     height: DebuggerWindow.size.height)

        Window("Print Queue", id: PrintQueueWindow.id) {
            PrintQueueView()
                .environmentObject(emulator)
        }
        .defaultSize(width: PrintQueueWindow.size.width,
                     height: PrintQueueWindow.size.height)

        Settings {
            SettingsView()
                .environmentObject(emulator)
                .environmentObject(aiSettings)
                .environmentObject(aiDocumentLibrary)
                .environmentObject(metadataSettings)
                .environmentObject(qLinkReloaded)
        }
        #endif
    }

    private func driveAccessModeBinding(for unit: Int) -> Binding<DriveAccessMode> {
        Binding {
            emulator.driveAccessMode(for: unit)
        } set: { accessMode in
            emulator.setDriveAccessMode(accessMode, for: unit)
        }
    }

    private func revealSharedFolder(_ configuration: DriveConfiguration) {
        guard let path = configuration.sharedFolderPath else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
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

        guard MacVICEEngineSession.isRunning else {
            return .terminateNow
        }

        guard !didRequestEngineTermination else {
            return .terminateLater
        }

        didRequestEngineTermination = true
        if !MacVICEEngineSession.requestQuit() {
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
        let togglesVideoStandard = arguments.contains("--vice-mac-smoke-toggle-video")

        return ViceMacLaunchConfiguration(
            releaseSmokeTest: ViceMacReleaseSmokeTestConfiguration(timeout: max(1, timeout),
                                                                  togglesVideoStandard: togglesVideoStandard)
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
    let togglesVideoStandard: Bool
}

private struct ReleaseSmokeTestView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    let configuration: ViceMacReleaseSmokeTestConfiguration

    var body: some View {
        MacVICEDisplayView(videoSource: emulator.frameSource,
                           inputHandlers: nil,
                           configuration: displayConfiguration)
            .frame(width: displaySize.width, height: displaySize.height)
            .background(Color.black)
    }

    private var displaySize: CGSize {
        emulator.frameSource.nativeDisplaySize()
    }

    private var displayConfiguration: MacVICEDisplayConfiguration {
        MacVICEDisplayConfiguration(forwardsInput: false,
                                    bootImageURL: emulator.frameSource.bootImageURL)
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
        var firstPassingFrame: MacVICEVideoFrame?
        var didRequestFirstVideoSwitch = false
        var didRequestSecondVideoSwitch = false
        let originalVideoStandard = emulator.videoStandard
        let alternateVideoStandard: EmulatorSession.VideoStandard = originalVideoStandard == .pal ? .ntsc : .pal

        while Date() < deadline {
            if let frame = emulator.frameSource.copyLatestFrame(after: lastSequence) {
                lastSequence = frame.sequence
                if let stats = ReleaseSmokeFrameAnalyzer.analyze(frame) {
                    lastStatus = stats.summary
                    if stats.passed && !configuration.togglesVideoStandard {
                        ReleaseSmokeTestProcess.succeed(
                            "VICE Mac release smoke test passed for \(emulator.machine.shortName): \(stats.summary)"
                        )
                    }
                    if stats.passed && configuration.togglesVideoStandard {
                        if firstPassingFrame == nil {
                            firstPassingFrame = frame
                            emulator.videoStandard = alternateVideoStandard
                            didRequestFirstVideoSwitch = true
                            lastStatus = "requested \(alternateVideoStandard.rawValue) after \(stats.summary)"
                        } else if didRequestFirstVideoSwitch,
                                  !didRequestSecondVideoSwitch,
                                  frame.height != firstPassingFrame?.height {
                            emulator.videoStandard = originalVideoStandard
                            didRequestSecondVideoSwitch = true
                            lastStatus = "requested \(originalVideoStandard.rawValue) after \(stats.summary)"
                        } else if didRequestSecondVideoSwitch,
                                  frame.height == firstPassingFrame?.height {
                            ReleaseSmokeTestProcess.succeed(
                                "VICE Mac video switch smoke test passed for \(emulator.machine.shortName): \(stats.summary)"
                            )
                        }
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
        MacVICEEngineSession.lastError
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
    static func analyze(_ frame: MacVICEVideoFrame) -> ReleaseSmokeFrameStats? {
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

private enum MediaLibraryWindow {
    static let id = "media-library"
    static let size = CGSize(width: 960, height: 640)
}

private enum DebuggerWindow {
    static let id = "debugger"
    static let size = CGSize(width: 1_320, height: 860)
}

private enum PrintQueueWindow {
    static let id = "print-queue"
    static let size = CGSize(width: 980, height: 720)
}

private struct PrintQueueView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var selectedPageID: PrinterSpoolPage.ID?

    var body: some View {
        VStack(spacing: 0) {
            printQueueToolbar

            Divider()

            HSplitView {
                pageList
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                pagePreview
                    .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            emulator.refreshPrintQueue()
            selectDefaultPage()
        }
        .onChange(of: emulator.printSpoolPages) { _, _ in
            normalizeSelection()
        }
    }

    private var printQueueToolbar: some View {
        HStack(spacing: 12) {
            Label(emulator.printQueueStatusTitle, systemImage: "printer")
                .font(.headline)

            Text(emulator.printerConfiguration.statusTitle)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Save as PDF...") {
                savePDF()
            }
            .disabled(emulator.printSpoolPages.isEmpty)

            Button("Print...") {
                emulator.printQueuedPages()
            }
            .disabled(emulator.printSpoolPages.isEmpty)

            Button("Clear") {
                emulator.clearPrintQueue()
                selectedPageID = nil
            }
            .disabled(emulator.printSpoolPages.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var pageList: some View {
        List(selection: $selectedPageID) {
            ForEach(Array(emulator.printSpoolPages.enumerated()), id: \.element.id) { index, page in
                HStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Page \(index + 1)")
                            .font(.body.weight(.medium))

                        Text(page.detailTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .tag(page.id)
                .padding(.vertical, 4)
            }
        }
        .overlay {
            if emulator.printSpoolPages.isEmpty {
                ContentUnavailableView("No Printed Pages",
                                       systemImage: "printer",
                                       description: Text("Completed GEOS printer pages will appear here."))
            }
        }
    }

    @ViewBuilder
    private var pagePreview: some View {
        if let selectedPage {
            ScrollView([.horizontal, .vertical]) {
                VStack {
                    PrintPagePreview(url: selectedPage.url)
                        .padding(28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.26))
        } else {
            ContentUnavailableView("Select a Page",
                                   systemImage: "doc.viewfinder",
                                   description: Text("Choose a printed page to preview it."))
        }
    }

    private var selectedPage: PrinterSpoolPage? {
        guard let selectedPageID else {
            return nil
        }

        return emulator.printSpoolPages.first { $0.id == selectedPageID }
    }

    private func selectDefaultPage() {
        selectedPageID = emulator.printSpoolPages.last?.id
    }

    private func normalizeSelection() {
        guard !emulator.printSpoolPages.isEmpty else {
            selectedPageID = nil
            return
        }

        if let selectedPageID,
           emulator.printSpoolPages.contains(where: { $0.id == selectedPageID }) {
            return
        }

        selectDefaultPage()
    }

    private func savePDF() {
        let panel = NSSavePanel()
        panel.title = "Save Printout"
        panel.message = "Save the queued printer pages as a PDF."
        panel.prompt = "Save"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(emulator.machine.shortName)-printout.pdf"

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.exportPrintQueuePDF(to: url)
    }
}

private struct PrintPagePreview: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 720, maxHeight: 900)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.separator.opacity(0.6))
                }
        } else {
            ContentUnavailableView("Unable to Preview Page",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(url.lastPathComponent))
        }
    }
}

struct QLinkReloadedAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    var kind: QLinkReloadedAlertKind = .message
}

enum QLinkReloadedAlertKind {
    case message
    case incompatibleSettings
}

@MainActor
final class QLinkReloadedService: ObservableObject {
    @Published var alert: QLinkReloadedAlert?
    @Published private(set) var configuredDiskTitle: String?
    @Published private(set) var configuredDiskVersionTitle: String?
    @Published private(set) var configuredDiskRegistrationProfile: QLinkReloadedRegistrationProfile?
    @Published private(set) var isConnecting = false
    @Published private(set) var registrationProfiles: [QLinkReloadedRegistrationProfile] = []

    private static let defaultsKey = "vice.qlinkReloaded.mediaItemID"
    private static let versionDefaultsKey = "vice.qlinkReloaded.diskVersion"
    private static let lastRegistrationAccessNumberDefaultsKey = "vice.qlinkReloaded.lastRegistrationAccessNumber"
    private static let legacyLastRegistrationUsernameDefaultsKey = "vice.qlinkReloaded.lastRegistrationUsername"
    private static let defaults = UserDefaults.standard
    private let registrationStore: QLinkReloadedRegistrationStoring

    init(registrationStore: QLinkReloadedRegistrationStoring = QLinkReloadedRegistrationKeychain()) {
        self.registrationStore = registrationStore
        refreshRegistrationProfiles()
        refreshConfiguredDiskTitle()
        refreshConfiguredDiskRegistrationProfile()
    }

    var hasConfiguredDisk: Bool {
        configuredDiskTitle != nil
    }

    func canConnect(machine: EmulatedMachine) -> Bool {
        supports(machine: machine) && hasConfiguredDisk && !isConnecting
    }

    func supports(machine: EmulatedMachine) -> Bool {
        switch machine.family {
        case .c64, .c128:
            return machine.capabilities.supportsNetworking
        case .pet, .vic20, .ted:
            return false
        }
    }

    func connect(emulator: EmulatorSession) {
        guard !isConnecting else {
            return
        }

        guard supports(machine: emulator.machine) else {
            presentError(title: "Q-Link Reloaded",
                         message: "Q-Link Reloaded can only be connected from a C64 or C128 machine with networking support.")
            return
        }

        guard hasConfiguredDisk else {
            presentError(title: "Q-Link Reloaded",
                         message: "Choose a Q-Link disk before connecting.")
            return
        }

        isConnecting = true

        Task { @MainActor in
            defer {
                isConnecting = false
            }

            await connectAndConfigure(emulator: emulator)
        }
    }

    func setQLinkRequiredSettingsAndConnect(emulator: EmulatorSession) {
        guard !isConnecting else {
            return
        }

        guard supports(machine: emulator.machine) else {
            presentError(title: "Q-Link Reloaded",
                         message: "Q-Link Reloaded can only be connected from a C64 or C128 machine with networking support.")
            return
        }

        guard hasConfiguredDisk else {
            presentError(title: "Q-Link Reloaded",
                         message: "Choose a Q-Link disk before connecting.")
            return
        }

        isConnecting = true

        Task { @MainActor in
            defer {
                isConnecting = false
            }

            await connectAndConfigure(emulator: emulator,
                                      allowSettingsOverride: true)
        }
    }

    private func connectAndConfigure(emulator: EmulatorSession,
                                     allowSettingsOverride: Bool = false) async {
        do {
            let modemPreparation = qLinkModemPreparation(for: emulator)
            var shouldApplyModemPreset = false
            var modemIssues: [String] = []
            var requiresSettingsConfirmation = false
            var noticeMessages: [String] = []
            switch modemPreparation {
            case .compatible:
                break
            case let .needsPreset(issues):
                shouldApplyModemPreset = true
                modemIssues = issues
            case let .incompatible(issues):
                shouldApplyModemPreset = true
                modemIssues = issues
                requiresSettingsConfirmation = true
            }

            let drivePreparation = qLinkDrivePreparation(for: emulator)
            var shouldApplyDrivePreset = false
            var driveIssues: [String] = []
            switch drivePreparation {
            case .compatible:
                break
            case let .needsPreset(issues):
                shouldApplyDrivePreset = true
                driveIssues = issues
            case let .incompatible(issues):
                shouldApplyDrivePreset = true
                driveIssues = issues
                requiresSettingsConfirmation = true
            }

            if requiresSettingsConfirmation && !allowSettingsOverride {
                presentIncompatibleSettings(modemIssues: modemIssues,
                                            driveIssues: driveIssues)
                return
            }

            let diskURL = try preparedDiskURL()
            guard let diskURL else {
                presentError(title: "Q-Link Reloaded",
                             message: "Choose a Q-Link disk before connecting.")
                return
            }

            if shouldApplyModemPreset {
                applyQLinkModemPreset(to: emulator)
                noticeMessages.append("enabled the Q-Link Reloaded modem preset: \(QLinkReloadedModemRequirements.summary)")
            }

            if shouldApplyDrivePreset {
                applyQLinkDrivePreset(to: emulator)
                noticeMessages.append("made drive 8 writable for the managed Q-Link disk")
            }

            if emulator.isMachineRunning {
                emulator.reset(kind: .hard)
            }

            guard emulator.attachDisk(to: 8,
                                      driveNumber: 0,
                                      url: diskURL,
                                      behavior: .run,
                                      programName: qLinkBootProgram(for: emulator.machine)) else {
                presentError(title: "Q-Link Reloaded",
                             message: "VICE Mac configured the modem, but the selected Q-Link disk could not be started.")
                return
            }

            emulator.statusText = "Q-Link Reloaded connecting through q-link.net:5190"
            if !noticeMessages.isEmpty {
                presentNotice(title: "Q-Link Reloaded",
                              message: "VICE Mac \(noticeMessages.joined(separator: " and ")).")
            }
        } catch {
            presentError(title: "Q-Link Reloaded", message: error.localizedDescription)
        }
    }

    func chooseDisk(for machine: EmulatedMachine) {
        guard supports(machine: machine) else {
            presentError(title: "Q-Link Reloaded",
                         message: "\(machine.displayName) does not support the Q-Link Reloaded preset.")
            return
        }

        do {
            _ = try importDisk(for: machine)
        } catch {
            presentError(title: "Q-Link Reloaded", message: error.localizedDescription)
        }
    }

    func forgetDisk() {
        Self.defaults.removeObject(forKey: Self.defaultsKey)
        Self.defaults.removeObject(forKey: Self.versionDefaultsKey)
        configuredDiskTitle = nil
        configuredDiskVersionTitle = nil
        configuredDiskRegistrationProfile = nil
    }

    func refreshRegistrationProfiles() {
        registrationProfiles = registrationStore.registrations()
    }

    func refreshConfiguredDiskRegistrationProfile() {
        do {
            guard let item = try configuredDiskItem(),
                  let url = try diskURL(for: item) else {
                configuredDiskRegistrationProfile = nil
                return
            }

            let data = try Data(contentsOf: url)
            configuredDiskRegistrationProfile = try QLinkReloadedDiskPatcher.registrationProfile(from: data)
        } catch {
            configuredDiskRegistrationProfile = nil
        }
    }

    func restoreRegistration(accessNumber: String) {
        do {
            guard let registration = registrationStore.loadRegistration(accessNumber: accessNumber) else {
                presentError(title: "Q-Link Reloaded",
                             message: "That saved Q-Link profile is no longer available.")
                refreshRegistrationProfiles()
                return
            }

            guard let item = try configuredDiskItem(),
                  let url = try diskURL(for: item) else {
                presentError(title: "Q-Link Reloaded",
                             message: "Choose a Q-Link disk before restoring a saved profile.")
                return
            }

            let version = try QLinkReloadedDiskPatcher.knownVersion(for: url)
            let patchResult = try QLinkReloadedDiskPatcher.configureReloadedProfile(at: url,
                                                                                    version: version,
                                                                                    restoring: registration)
            Self.defaults.set(registration.accessNumber, forKey: Self.lastRegistrationAccessNumberDefaultsKey)
            Self.defaults.set(patchResult.version.displayTitle, forKey: Self.versionDefaultsKey)
            configuredDiskVersionTitle = patchResult.version.displayTitle
            configuredDiskRegistrationProfile = registration
            refreshRegistrationProfiles()

            let state = patchResult.changedDisk ? "restored" : "already matches"
            presentNotice(title: "Q-Link Reloaded",
                          message: "\(registration.displayTitle) \(state) on the managed Q-Link disk.")
        } catch {
            presentError(title: "Q-Link Reloaded", message: error.localizedDescription)
        }
    }

    func copyRegistrationFromConfiguredDisk() {
        do {
            guard let item = try configuredDiskItem(),
                  let url = try diskURL(for: item) else {
                presentError(title: "Q-Link Reloaded",
                             message: "Choose a Q-Link disk before copying a profile from disk.")
                return
            }

            let data = try Data(contentsOf: url)
            guard let registration = try QLinkReloadedDiskPatcher.registrationProfile(from: data) else {
                configuredDiskRegistrationProfile = nil
                presentNotice(title: "Q-Link Reloaded",
                              message: "The configured Q-Link disk does not contain a saved profile.")
                return
            }

            registrationStore.saveRegistration(registration)
            Self.defaults.set(registration.accessNumber, forKey: Self.lastRegistrationAccessNumberDefaultsKey)
            configuredDiskRegistrationProfile = registration
            refreshRegistrationProfiles()
            presentNotice(title: "Q-Link Reloaded",
                          message: "Copied \(registration.displayTitle) from disk to Keychain.")
        } catch {
            configuredDiskRegistrationProfile = nil
            presentError(title: "Q-Link Reloaded", message: error.localizedDescription)
        }
    }

    func removeRegistrationFromConfiguredDisk() {
        do {
            guard let item = try configuredDiskItem(),
                  let url = try diskURL(for: item) else {
                presentError(title: "Q-Link Reloaded",
                             message: "Choose a Q-Link disk before removing a profile from disk.")
                return
            }

            let version = try QLinkReloadedDiskPatcher.knownVersion(for: url)
            let patchResult = try QLinkReloadedDiskPatcher.removeRegistrationProfile(at: url,
                                                                                     version: version)
            Self.defaults.set(patchResult.version.displayTitle, forKey: Self.versionDefaultsKey)
            configuredDiskVersionTitle = patchResult.version.displayTitle
            configuredDiskRegistrationProfile = nil
            refreshRegistrationProfiles()

            let state = patchResult.changedDisk ? "removed" : "already empty"
            presentNotice(title: "Q-Link Reloaded",
                          message: "The profile on the managed Q-Link disk is \(state). Saved Keychain profiles were not changed.")
        } catch {
            presentError(title: "Q-Link Reloaded", message: error.localizedDescription)
        }
    }

    func deleteRegistration(accessNumber: String) {
        registrationStore.deleteRegistration(accessNumber: accessNumber)
        if Self.defaults.string(forKey: Self.lastRegistrationAccessNumberDefaultsKey) == accessNumber {
            Self.defaults.removeObject(forKey: Self.lastRegistrationAccessNumberDefaultsKey)
        }
        if Self.defaults.string(forKey: Self.legacyLastRegistrationUsernameDefaultsKey) == accessNumber {
            Self.defaults.removeObject(forKey: Self.legacyLastRegistrationUsernameDefaultsKey)
        }
        refreshRegistrationProfiles()
    }

    private func preparedDiskURL() throws -> URL? {
        if let item = try configuredDiskItem(),
           let url = try diskURL(for: item) {
            try refreshManagedDiskPatch(at: url)
            return url
        }

        return nil
    }

    private func qLinkBootProgram(for machine: EmulatedMachine) -> String {
        machine.family == .c128 ? "boot128" : "boot64"
    }

    private func refreshManagedDiskPatch(at url: URL) throws {
        let version = try QLinkReloadedDiskPatcher.knownVersion(for: url)
        let patchResult = try configureManagedDisk(at: url,
                                                   version: version)
        Self.defaults.set(patchResult.version.displayTitle, forKey: Self.versionDefaultsKey)
        configuredDiskVersionTitle = patchResult.version.displayTitle
    }

    private func importDisk(for machine: EmulatedMachine) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Q-Link Disk"
        panel.message = "Choose your Quantum Link disk image. VICE Mac will copy it into the media library and use it for one-click Q-Link Reloaded connections."
        panel.prompt = "Use Disk"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = diskContentTypes(for: machine)

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let sourceURL = panel.url else {
            return nil
        }

        let diskVersion = try QLinkReloadedDiskPatcher.knownVersion(for: sourceURL)
        let store = try MediaLibraryStore()
        let importedItems = try store.importURLs([sourceURL])
        guard let item = importedItems.first(where: { $0.primaryFile.kind == .disk }) else {
            throw QLinkReloadedServiceError.unsupportedDisk
        }
        let managedURL = store.primaryFileURL(for: item)
        let patchResult = try configureManagedDisk(at: managedURL,
                                                   version: diskVersion)

        Self.defaults.set(item.id.uuidString, forKey: Self.defaultsKey)
        Self.defaults.set(patchResult.version.displayTitle, forKey: Self.versionDefaultsKey)
        configuredDiskTitle = item.title
        configuredDiskVersionTitle = patchResult.version.displayTitle
        refreshConfiguredDiskRegistrationProfile()
        return managedURL
    }

    private func configureManagedDisk(at url: URL,
                                      version: QLinkReloadedDiskVersion) throws -> QLinkReloadedDiskPatchResult {
        var data = try Data(contentsOf: url)
        let diskRegistration = try saveRegistrationIfPresent(in: data)
        let changedDisk = try QLinkReloadedDiskPatcher.configureReloadedProfile(in: &data,
                                                                                restoring: nil)
        if changedDisk {
            try data.write(to: url, options: .atomic)
        }

        if let diskRegistration {
            Self.defaults.set(diskRegistration.accessNumber, forKey: Self.lastRegistrationAccessNumberDefaultsKey)
        }

        configuredDiskRegistrationProfile = try QLinkReloadedDiskPatcher.registrationProfile(from: data)
        return QLinkReloadedDiskPatchResult(version: version,
                                            changedDisk: changedDisk)
    }

    @discardableResult
    private func saveRegistrationIfPresent(in data: Data) throws -> QLinkReloadedRegistrationProfile? {
        guard let registration = try QLinkReloadedDiskPatcher.registrationProfile(from: data) else {
            return nil
        }

        registrationStore.saveRegistration(registration)
        Self.defaults.set(registration.accessNumber, forKey: Self.lastRegistrationAccessNumberDefaultsKey)
        refreshRegistrationProfiles()
        return registration
    }

    private func configuredDiskItem() throws -> MediaLibraryItem? {
        guard let rawID = Self.defaults.string(forKey: Self.defaultsKey),
              let id = UUID(uuidString: rawID) else {
            configuredDiskTitle = nil
            configuredDiskVersionTitle = nil
            configuredDiskRegistrationProfile = nil
            return nil
        }

        let store = try MediaLibraryStore()
        guard let item = try store.items().first(where: { $0.id == id }) else {
            Self.defaults.removeObject(forKey: Self.defaultsKey)
            Self.defaults.removeObject(forKey: Self.versionDefaultsKey)
            configuredDiskTitle = nil
            configuredDiskVersionTitle = nil
            configuredDiskRegistrationProfile = nil
            return nil
        }

        configuredDiskTitle = item.title
        configuredDiskVersionTitle = Self.defaults.string(forKey: Self.versionDefaultsKey)
        return item
    }

    private func diskURL(for item: MediaLibraryItem) throws -> URL? {
        let store = try MediaLibraryStore()
        let url = store.primaryFileURL(for: item)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Self.defaults.removeObject(forKey: Self.defaultsKey)
            Self.defaults.removeObject(forKey: Self.versionDefaultsKey)
            configuredDiskTitle = nil
            configuredDiskVersionTitle = nil
            configuredDiskRegistrationProfile = nil
            return nil
        }

        return url
    }

    private func refreshConfiguredDiskTitle() {
        _ = try? configuredDiskItem()
    }

    private func qLinkModemPreparation(for emulator: EmulatorSession) -> QLinkReloadedModemPreparation {
        let issues = QLinkReloadedModemRequirements.incompatibilities(in: emulator.networkModem,
                                                                      for: emulator.machine)
        if issues.isEmpty {
            return .compatible
        }

        let defaultModem = NetworkModemConfiguration.standard.normalized(for: emulator.machine)
        guard !EmulatorDefaults.hasSavedNetworkModem(for: emulator.machine),
              emulator.networkModem == defaultModem else {
            return .incompatible(issues)
        }

        return .needsPreset(issues)
    }

    private func qLinkDrivePreparation(for emulator: EmulatorSession) -> QLinkReloadedDrivePreparation {
        let issues = QLinkReloadedDriveRequirements.incompatibilities(in: emulator.driveConfigurations,
                                                                      for: emulator.machine)
        if issues.isEmpty {
            return .compatible
        }

        let defaultDrives = emulator.machine.defaultDriveConfigurations()
        guard !EmulatorDefaults.hasSavedDriveConfigurations(for: emulator.machine),
              emulator.driveConfigurations == defaultDrives else {
            return .incompatible(issues)
        }

        return .needsPreset(issues)
    }

    private func applyQLinkModemPreset(to emulator: EmulatorSession) {
        let configuration = QLinkReloadedModemRequirements.preset(preservingValuesFrom: emulator.networkModem)
        emulator.networkModem = configuration.normalized(for: emulator.machine)
    }

    private func applyQLinkDrivePreset(to emulator: EmulatorSession) {
        emulator.driveConfigurations = QLinkReloadedDriveRequirements.preset(preservingValuesFrom: emulator.driveConfigurations,
                                                                             for: emulator.machine)
    }

    private func diskContentTypes(for machine: EmulatedMachine) -> [UTType] {
        let extensions = Set(machine.capabilities.driveTypes
            .flatMap(\.supportedDiskImageTypes)
            .map(\.rawValue))

        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.data] : types
    }

    private func presentError(title: String, message: String) {
        alert = QLinkReloadedAlert(title: title, message: message)
    }

    private func presentNotice(title: String, message: String) {
        alert = QLinkReloadedAlert(title: title, message: message)
    }

    private func presentIncompatibleSettings(modemIssues: [String], driveIssues: [String]) {
        alert = QLinkReloadedAlert(title: "Q-Link Reloaded",
                                   message: QLinkReloadedServiceError.incompatibleSettings(modemIssues: modemIssues,
                                                                                          driveIssues: driveIssues)
                                       .localizedDescription,
                                   kind: .incompatibleSettings)
    }
}

private enum QLinkReloadedModemPreparation: Equatable {
    case compatible
    case needsPreset([String])
    case incompatible([String])
}

private enum QLinkReloadedDrivePreparation: Equatable {
    case compatible
    case needsPreset([String])
    case incompatible([String])
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

    static func openDisk(for emulator: EmulatorSession,
                         unit: Int,
                         driveNumber: Int = 0,
                         autorun: Bool) {
        guard let configuration = emulator.driveConfigurations.first(where: { $0.unit == unit }) else {
            return
        }

        guard configuration.storageKind != .sharedFolder else {
            emulator.statusText = "Drive \(unit) is a Shared Mac Folder"
            return
        }

        let extensions = configuration.driveType.supportedDiskImageTypes.map(\.rawValue)
        let destinationTitle = configuration.driveType.slotCount > 1
            ? "drive \(unit):\(driveNumber)"
            : "drive \(unit)"
        let panel = openPanel(title: configuration.storageKind == .hardDriveImage ? "Attach Hard Drive Image" : "Attach Disk",
                              message: "Choose a \(configuration.driveType.supportedDiskImageDescription) image for \(destinationTitle).",
                              prompt: autorun ? "Attach and Run" : "Attach",
                              filenameExtensions: extensions)

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachDisk(to: unit,
                            driveNumber: driveNumber,
                            url: url,
                            autorun: autorun)
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
        panel.message = "Save the current \(emulator.machineDisplayName) machine state. \(emulator.snapshotConfiguration.summaryTitle)."
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

    static func exportScreenshot(for emulator: EmulatorSession) {
        let panel = NSSavePanel()
        panel.title = "Export Screenshot"
        panel.message = "Export the current \(emulator.machineDisplayName) screen as a PNG image."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(emulator.machine.shortName)-Screenshot.png"
        panel.allowedContentTypes = [.png]

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        let screenshotURL = url.pathExtension.lowercased() == "png"
            ? url
            : url.appendingPathExtension("png")
        emulator.exportScreenshot(url: screenshotURL)
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
                            Text(AppMetadata.brandDisplayName(viceTarget: emulator.machine.shortName))
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
    static let brandName = "mac VICE"

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? brandName
    }

    static func brandDisplayName(viceTarget: String?) -> String {
        guard let viceTarget,
              !viceTarget.isEmpty else {
            return brandName
        }

        return "\(brandName) (\(viceTarget))"
    }

    static var viceVersionLine: String {
        "VICE \(viceVersion)"
    }

    static var buildMetadata: AppBuildMetadata {
        AppBuildMetadata(macSHA: buildMetadataString(for: "VICEMacGitSHA"),
                         viceUpstreamSHA: buildMetadataString(for: "VICEUpstreamGitSHA"))
    }

    static func copyVersionSummary(machineName: String, viceTarget: String) {
        let metadata = buildMetadata
        let summary = """
        \(brandDisplayName(viceTarget: viceTarget))
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
        MacVICEEngineSession.version
    }

    private static func bundleString(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return "unknown"
        }

        return value
    }

    private static func buildMetadataString(for key: String) -> String {
        if let value = bundledBuildMetadata[key] as? String,
           !value.isEmpty {
            return value
        }

        return bundleString(for: key)
    }

    private static var bundledBuildMetadata: [String: Any] {
        guard let url = Bundle.main.url(forResource: "VICEBuildMetadata", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dictionary = try? PropertyListSerialization.propertyList(from: data,
                                                                           options: [],
                                                                           format: nil) as? [String: Any] else {
            return [:]
        }

        return dictionary
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

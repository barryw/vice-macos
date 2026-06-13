import CMacVICEEngineBridge
import Foundation

private let macVICEFrameCallback: @convention(c) (
    UnsafePointer<ViceEngineVideoFrame>?,
    UnsafeMutableRawPointer?
) -> Void = { framePointer, context in
    guard let framePointer,
          let context,
          let pixels = framePointer.pointee.pixels else {
        return
    }

    let frame = framePointer.pointee
    let byteCount = UInt64(frame.stride) * UInt64(frame.height)
    guard frame.pixelFormat == 1,
          frame.width > 0,
          frame.height > 0,
          UInt64(frame.stride) >= UInt64(frame.width) * 4,
          byteCount <= UInt64(Int.max) else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    let pixelData = Data(bytes: pixels, count: Int(byteCount))

    let videoFrame = MacVICEVideoFrame(width: Int(frame.width),
                                       height: Int(frame.height),
                                       bytesPerRow: Int(frame.stride),
                                       sequence: frame.sequence,
                                       pixels: pixelData)
    session.videoSource.publish(videoFrame)
    session.callbacks.videoFrame?(videoFrame)
}

private let macVICEAudioCallback: @convention(c) (
    UnsafePointer<ViceEngineAudioSamples>?,
    UnsafeMutableRawPointer?
) -> Void = { samplesPointer, context in
    guard let samplesPointer,
          let context,
          let samples = samplesPointer.pointee.samples else {
        return
    }

    let raw = samplesPointer.pointee
    let sampleCount = UInt64(raw.frameCount) * UInt64(raw.channelCount)
    let byteCount = sampleCount * UInt64(MemoryLayout<Int16>.stride)
    guard raw.frameCount > 0,
          raw.channelCount > 0,
          byteCount <= UInt64(Int.max) else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    let audioSamples = MacVICEAudioSamples(samples: Data(bytes: samples, count: Int(byteCount)),
                                           frameCount: Int(raw.frameCount),
                                           channelCount: Int(raw.channelCount),
                                           sampleRate: Int(raw.sampleRate),
                                           sequence: raw.sequence)
    session.audioSource.publish(audioSamples)
    session.callbacks.audioSamples?(audioSamples)
}

private let macVICEDriveStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineDriveStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    session.callbacks.driveStatus?(MacVICEDriveStatus(raw: statusPointer.pointee))
}

private let macVICECartridgeStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineCartridgeStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    session.callbacks.cartridgeStatus?(MacVICECartridgeStatus(raw: statusPointer.pointee))
}

private let macVICEVSIDStateCallback: @convention(c) (
    UnsafePointer<ViceEngineVSIDState>?,
    UnsafeMutableRawPointer?
) -> Void = { statePointer, context in
    guard let statePointer,
          let context else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    session.callbacks.vsidState?(MacVICEVSIDState(raw: statePointer.pointee))
}

private let macVICESIDVoiceSamplesCallback: @convention(c) (
    UnsafePointer<ViceEngineSIDVoiceSamples>?,
    UnsafeMutableRawPointer?
) -> Void = { samplesPointer, context in
    guard let samplesPointer,
          let context,
          let samples = samplesPointer.pointee.samples else {
        return
    }

    let raw = samplesPointer.pointee
    let sampleCount = UInt64(raw.frameCount) * UInt64(raw.voiceCount)
    let byteCount = sampleCount * UInt64(MemoryLayout<Int16>.stride)
    guard raw.frameCount > 0,
          raw.voiceCount > 0,
          raw.voiceCount <= VICE_ENGINE_SID_VOICE_COUNT,
          byteCount <= UInt64(Int.max) else {
        return
    }

    let session = Unmanaged<MacVICEEngineSession>.fromOpaque(context).takeUnretainedValue()
    session.callbacks.sidVoiceSamples?(MacVICESIDVoiceSamples(raw: raw,
                                                              samples: Data(bytes: samples, count: Int(byteCount))))
}

/// Callback hooks for events emitted by a running VICE engine session.
public struct MacVICEEngineCallbacks {
    /// Called after each accepted video frame.
    public var videoFrame: ((MacVICEVideoFrame) -> Void)?
    /// Called after each accepted interleaved PCM audio packet.
    public var audioSamples: ((MacVICEAudioSamples) -> Void)?
    /// Called when VICE reports drive activity or media state.
    public var driveStatus: ((MacVICEDriveStatus) -> Void)?
    /// Called when cartridge attach state changes.
    public var cartridgeStatus: ((MacVICECartridgeStatus) -> Void)?
    /// Called when VSID publishes tune metadata.
    public var vsidState: ((MacVICEVSIDState) -> Void)?
    /// Called when VICE publishes per-SID-voice sample data.
    public var sidVoiceSamples: ((MacVICESIDVoiceSamples) -> Void)?

    /// Creates a set of optional engine callbacks.
    public init(videoFrame: ((MacVICEVideoFrame) -> Void)? = nil,
                audioSamples: ((MacVICEAudioSamples) -> Void)? = nil,
                driveStatus: ((MacVICEDriveStatus) -> Void)? = nil,
                cartridgeStatus: ((MacVICECartridgeStatus) -> Void)? = nil,
                vsidState: ((MacVICEVSIDState) -> Void)? = nil,
                sidVoiceSamples: ((MacVICESIDVoiceSamples) -> Void)? = nil) {
        self.videoFrame = videoFrame
        self.audioSamples = audioSamples
        self.driveStatus = driveStatus
        self.cartridgeStatus = cartridgeStatus
        self.vsidState = vsidState
        self.sidVoiceSamples = sidVoiceSamples
    }
}

/// Result of starting a VICE engine session.
public enum MacVICEEngineStartResult: Sendable, Equatable {
    /// The engine accepted the launch request and started a machine.
    case started
    /// A VICE engine was already running in the process.
    case alreadyRunning
}

/// Tape deck command values understood by the VICE bridge.
public enum MacVICETapeCommand: Int32, CaseIterable, Sendable {
    /// Stop tape playback or recording.
    case stop = 0
    /// Start tape playback.
    case play = 1
    /// Fast-forward the tape.
    case fastForward = 2
    /// Rewind the tape.
    case rewind = 3
    /// Start tape recording.
    case record = 4
    /// Reset tape transport state.
    case reset = 5
    /// Reset the tape counter.
    case resetCounter = 6
}

/// Drive status reported by VICE.
public struct MacVICEDriveStatus: Sendable, Equatable {
    /// IEC unit number.
    public let unit: Int
    /// Whether the drive is enabled.
    public let enabled: Bool
    /// Raw VICE drive type identifier.
    public let driveType: Int32
    /// Active drive number for dual-drive devices.
    public let activeDriveNumber: UInt32
    /// Raw VICE LED color value.
    public let ledColor: UInt32
    /// Current aggregate drive LED intensity.
    public let ledIntensity: UInt32
    /// Current drive error LED intensity.
    public let errorIntensity: UInt32
    /// Current LED intensity for drive 0.
    public let drive0LEDIntensity: UInt32
    /// Current LED intensity for drive 1.
    public let drive1LEDIntensity: UInt32
    /// Current whole track, when VICE reports one.
    public let track: UInt32?
    /// Current half-track, when VICE reports one.
    public let halfTrack: UInt32?
    /// Current disk side.
    public let diskSide: UInt32
    /// Raw VICE drive status code.
    public let driveStatusCode: Int32
    /// Human-readable VICE drive status text, when available.
    public let driveStatusText: String?
    /// Attached image path for the active drive, when available.
    public let imagePath: String?
    /// Attached image path for drive 0, when available.
    public let drive0ImagePath: String?
    /// Attached image path for drive 1, when available.
    public let drive1ImagePath: String?

    /// Creates a drive status value.
    public init(unit: Int,
                enabled: Bool,
                driveType: Int32,
                activeDriveNumber: UInt32,
                ledColor: UInt32,
                ledIntensity: UInt32,
                errorIntensity: UInt32,
                drive0LEDIntensity: UInt32,
                drive1LEDIntensity: UInt32,
                track: UInt32?,
                halfTrack: UInt32?,
                diskSide: UInt32,
                driveStatusCode: Int32,
                driveStatusText: String?,
                imagePath: String?,
                drive0ImagePath: String?,
                drive1ImagePath: String?) {
        self.unit = unit
        self.enabled = enabled
        self.driveType = driveType
        self.activeDriveNumber = activeDriveNumber
        self.ledColor = ledColor
        self.ledIntensity = ledIntensity
        self.errorIntensity = errorIntensity
        self.drive0LEDIntensity = drive0LEDIntensity
        self.drive1LEDIntensity = drive1LEDIntensity
        self.track = track
        self.halfTrack = halfTrack
        self.diskSide = diskSide
        self.driveStatusCode = driveStatusCode
        self.driveStatusText = driveStatusText
        self.imagePath = imagePath
        self.drive0ImagePath = drive0ImagePath
        self.drive1ImagePath = drive1ImagePath
    }
}

/// Cartridge status reported by VICE.
public struct MacVICECartridgeStatus: Sendable, Equatable {
    /// Whether a cartridge image is attached.
    public let isAttached: Bool
    /// Raw VICE cartridge identifier.
    public let cartridgeID: Int32
    /// Raw VICE cartridge flags.
    public let cartridgeFlags: UInt32
    /// ROM size in bytes.
    public let romSize: UInt32
    /// Number of cartridge chips.
    public let chipCount: UInt32
    /// Number of cartridge banks.
    public let bankCount: UInt32
    /// Human-readable cartridge name, when VICE reports one.
    public let cartridgeName: String?
    /// Attached cartridge image path, when available.
    public let imagePath: String?

    /// Creates a cartridge status value.
    public init(isAttached: Bool,
                cartridgeID: Int32,
                cartridgeFlags: UInt32,
                romSize: UInt32,
                chipCount: UInt32,
                bankCount: UInt32,
                cartridgeName: String?,
                imagePath: String?) {
        self.isAttached = isAttached
        self.cartridgeID = cartridgeID
        self.cartridgeFlags = cartridgeFlags
        self.romSize = romSize
        self.chipCount = chipCount
        self.bankCount = bankCount
        self.cartridgeName = cartridgeName
        self.imagePath = imagePath
    }
}

/// Metadata reported by the VICE SID player.
public struct MacVICEVSIDState: Sendable, Equatable {
    /// Tune title.
    public let name: String
    /// Tune author.
    public let author: String
    /// Tune copyright or release information.
    public let copyright: String
    /// IRQ mode text reported by VICE.
    public let irq: String
    /// Driver metadata reported by VICE.
    public let driverInfo: String
    /// Raw VSID sync value.
    public let sync: UInt32
    /// Raw VICE SID model identifier.
    public let sidModel: Int32
    /// Currently selected tune number.
    public let currentTune: UInt32
    /// Number of tunes in the SID file.
    public let tuneCount: UInt32
    /// Default tune number.
    public let defaultTune: UInt32
    /// Tune length in deciseconds, when known.
    public let deciseconds: UInt32
    /// Driver address.
    public let driverAddress: UInt32
    /// SID file load address.
    public let loadAddress: UInt32
    /// SID init routine address.
    public let initAddress: UInt32
    /// SID play routine address.
    public let playAddress: UInt32
    /// SID payload size in bytes.
    public let dataSize: UInt32

    /// Creates VSID state metadata.
    public init(name: String,
                author: String,
                copyright: String,
                irq: String,
                driverInfo: String,
                sync: UInt32,
                sidModel: Int32,
                currentTune: UInt32,
                tuneCount: UInt32,
                defaultTune: UInt32,
                deciseconds: UInt32,
                driverAddress: UInt32,
                loadAddress: UInt32,
                initAddress: UInt32,
                playAddress: UInt32,
                dataSize: UInt32) {
        self.name = name
        self.author = author
        self.copyright = copyright
        self.irq = irq
        self.driverInfo = driverInfo
        self.sync = sync
        self.sidModel = sidModel
        self.currentTune = currentTune
        self.tuneCount = tuneCount
        self.defaultTune = defaultTune
        self.deciseconds = deciseconds
        self.driverAddress = driverAddress
        self.loadAddress = loadAddress
        self.initAddress = initAddress
        self.playAddress = playAddress
        self.dataSize = dataSize
    }
}

/// Per-voice SID sample data captured from VICE.
public struct MacVICESIDVoiceSamples: Sendable, Equatable {
    /// Number of voices emitted per SID chip.
    public static let voiceCountPerChip = Int(VICE_ENGINE_SID_VOICE_COUNT)

    /// Interleaved signed 16-bit samples for each voice.
    public let samples: Data
    /// Number of sample frames per voice.
    public let frameCount: Int
    /// Number of voices in the packet.
    public let voiceCount: Int
    /// SID chip index for this packet.
    public let chipIndex: Int
    /// Audio sample rate in hertz.
    public let sampleRate: UInt32
    /// Machine clock rate in hertz.
    public let clockRate: UInt32
    /// Current SID frequency register values by voice.
    public let frequencies: [UInt16]
    /// Current SID control register values by voice.
    public let controls: [UInt8]
    /// Monotonic packet sequence assigned by the VICE bridge.
    public let sequence: UInt64

    /// Creates per-voice SID sample data.
    public init(samples: Data,
                frameCount: Int,
                voiceCount: Int,
                chipIndex: Int,
                sampleRate: UInt32,
                clockRate: UInt32,
                frequencies: [UInt16],
                controls: [UInt8],
                sequence: UInt64) {
        self.samples = samples
        self.frameCount = frameCount
        self.voiceCount = voiceCount
        self.chipIndex = chipIndex
        self.sampleRate = sampleRate
        self.clockRate = clockRate
        self.frequencies = frequencies
        self.controls = controls
        self.sequence = sequence
    }
}

/// Owns one embedded VICE engine session and exposes high-level control APIs.
///
/// VICE currently runs as a process-wide engine. Create one active
/// `MacVICEEngineSession` at a time unless the bridge explicitly grows
/// multi-instance support.
public final class MacVICEEngineSession {
    /// Configuration used to create this session.
    public let configuration: MacVICEMachineConfiguration
    /// Video source populated by engine frame callbacks.
    public let videoSource: MacVICEFrameSource
    /// Audio source populated by engine audio callbacks.
    public let audioSource: MacVICEAudioSampleSource
    /// Optional callbacks for engine events.
    public var callbacks: MacVICEEngineCallbacks
    /// Monitor/debugger API for the running machine.
    public lazy var debugger = MacVICEDebugger(session: self)

    private var launchPlan: MacVICELaunchPlan?

    /// Creates a session from a machine configuration.
    public init(configuration: MacVICEMachineConfiguration,
                videoSource: MacVICEFrameSource? = nil,
                audioSource: MacVICEAudioSampleSource = MacVICEAudioSampleSource(),
                callbacks: MacVICEEngineCallbacks = MacVICEEngineCallbacks()) {
        self.configuration = configuration
        self.videoSource = videoSource ?? MacVICEFrameSource(displayProfile: configuration.machine.displayProfile)
        self.audioSource = audioSource
        self.callbacks = callbacks
    }

    /// Whether any VICE machine is currently running in the process.
    public var isRunning: Bool {
        Self.isRunning
    }

    /// VICE engine version string reported by the loaded bridge.
    public var version: String {
        Self.version
    }

    /// Whether any VICE machine is currently running in the process.
    public static var isRunning: Bool {
        ViceEngineIsRunning()
    }

    /// VICE engine version string reported by the loaded bridge.
    public static var version: String {
        guard let version = ViceEngineGetVersion() else {
            return "unknown"
        }
        return String(cString: version)
    }

    /// Resolves the configured runtime and starts the machine.
    public func start() throws {
        let plan = try configuration.launchPlan()
        launchPlan = plan
        _ = try start(launchPlan: plan)
    }

    /// Starts the machine from a previously resolved launch plan.
    @discardableResult
    public func start(launchPlan plan: MacVICELaunchPlan) throws -> MacVICEEngineStartResult {
        launchPlan = plan
        return try start(machineID: plan.machine.viceTarget,
                         dynamicLibraryURL: plan.dynamicLibraryURL,
                         arguments: plan.arguments)
    }

    /// Starts a machine using fully explicit bridge inputs.
    ///
    /// Most consumers should call `start()` or `start(launchPlan:)`.
    @discardableResult
    public func start(machineID: String,
                      dynamicLibraryURL: URL,
                      arguments: [String]) throws -> MacVICEEngineStartResult {
        installCallbacks()
        let started = arguments.withMacVICECStringArray { argc, argv in
            machineID.withCString { machineIDPointer in
                dynamicLibraryURL.path.withCString { dynamicLibraryPath in
                    ViceEngineStartMachine(machineIDPointer,
                                           dynamicLibraryPath,
                                           argc,
                                           argv)
                }
            }
        } ?? false

        if started {
            return .started
        }

        guard Self.isRunning else {
            throw MacVICEError.engineFailure(Self.lastErrorMessage)
        }

        return .alreadyRunning
    }

    private func installCallbacks() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        ViceEngineSetVideoFrameCallback(macVICEFrameCallback, context)
        ViceEngineSetAudioSamplesCallback(macVICEAudioCallback, context)
        ViceEngineSetDriveStatusCallback(macVICEDriveStatusCallback, context)
        ViceEngineSetCartridgeStatusCallback(macVICECartridgeStatusCallback, context)
        ViceEngineSetVSIDStateCallback(macVICEVSIDStateCallback, context)
        ViceEngineSetSIDVoiceSamplesCallback(macVICESIDVoiceSamplesCallback, context)
    }

    /// Requests the running VICE engine to quit.
    @discardableResult
    public func requestQuit() -> Bool {
        Self.requestQuit()
    }

    /// Requests the process-wide VICE engine to quit.
    @discardableResult
    public static func requestQuit() -> Bool {
        ViceEngineRequestQuit()
    }

    /// Pauses or resumes the running machine.
    @discardableResult
    public func setPauseEnabled(_ paused: Bool) -> Bool {
        ViceEngineSetPauseEnabled(paused)
    }

    /// Resets the running machine.
    @discardableResult
    public func reset(hard: Bool = false) -> Bool {
        ViceEngineTriggerMachineReset(hard)
    }

    /// Enables or disables VICE warp mode.
    @discardableResult
    public func setWarpMode(_ enabled: Bool) -> Bool {
        ViceEngineSetWarpMode(enabled)
    }

    /// Enables or disables VICE system time synchronization.
    @discardableResult
    public func setSystemTimeSyncEnabled(_ enabled: Bool) -> Bool {
        ViceEngineSetSystemTimeSyncEnabled(enabled)
    }

    /// Changes the running machine's video standard through the safest VICE path for that machine.
    ///
    /// Some machines couple PAL/NTSC timing to a full VICE model selection. TED-family machines
    /// are the important case: setting `MachineVideoStandard` alone can leave the machine with
    /// mismatched timing, ROM, and device state. This method uses VICE model setters when the
    /// selected machine has a video-standard-specific model, and falls back to the raw video
    /// standard resource only for machines where that is the native VICE operation.
    @discardableResult
    public func setVideoStandard(_ videoStandard: MacVICEVideoStandard,
                                 machine: MacVICEMachine,
                                 model preferredModel: String? = nil) -> Bool {
        if let model = machine.runtimeModel(for: videoStandard,
                                            preferredModel: preferredModel) {
            return setMachineModel(model)
        }

        return setIntResource("MachineVideoStandard",
                              value: videoStandard.machineVideoStandardResourceValue)
    }

    /// Changes the active VICE model by model name.
    @discardableResult
    public func setMachineModel(_ model: String) -> Bool {
        model.withCString { modelName in
            ViceEngineSetMachineModel(modelName)
        }
    }

    /// Sets a raw VICE integer resource.
    @discardableResult
    public func setIntResource(_ name: String, value: Int32) -> Bool {
        name.withCString { resourceName in
            ViceEngineSetIntResource(resourceName, value)
        }
    }

    /// Sets a raw VICE string resource.
    @discardableResult
    public func setStringResource(_ name: String, value: String) -> Bool {
        name.withCString { resourceName in
            value.withCString { resourceValue in
                ViceEngineSetStringResource(resourceName, resourceValue)
            }
        }
    }

    /// Reads a raw VICE integer resource.
    public func intResource(_ name: String) -> Int32? {
        var value: Int32 = 0
        let didRead = name.withCString { resourceName in
            ViceEngineGetIntResource(resourceName, &value)
        }
        return didRead ? value : nil
    }

    /// Reads a raw VICE string resource.
    public func stringResource(_ name: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let didRead = name.withCString { resourceName in
            buffer.withUnsafeMutableBufferPointer { pointer in
                guard let baseAddress = pointer.baseAddress else {
                    return false
                }

                return ViceEngineGetStringResource(resourceName,
                                                   baseAddress,
                                                   UInt32(pointer.count))
            }
        }
        return didRead ? String(cString: buffer) : nil
    }

    /// Autostarts media in the running machine.
    @discardableResult
    public func autostart(_ url: URL, runMode: MacVICEMediaRunMode = .run) -> Bool {
        url.path.withCString { path in
            ViceEngineAutostartMedia(path, runMode.rawValue)
        }
    }

    /// Attaches a disk image to an IEC unit and drive.
    @discardableResult
    public func attachDisk(unit: UInt32 = 8,
                           drive: UInt32 = 0,
                           url: URL,
                           runMode: MacVICEMediaRunMode = .attach) -> Bool {
        url.path.withCString { path in
            ViceEngineAttachDisk(unit, drive, path, runMode.rawValue)
        }
    }

    /// Detaches the disk image for an IEC unit and drive.
    @discardableResult
    public func detachDisk(unit: UInt32 = 8, drive: UInt32 = 0) -> Bool {
        ViceEngineDetachDisk(unit, drive)
    }

    /// Resets an emulated IEC drive.
    @discardableResult
    public func resetDrive(unit: UInt32) -> Bool {
        ViceEngineResetDrive(unit)
    }

    /// Plays a short drive sound preview for an emulated IEC drive.
    @discardableResult
    public func previewDriveSound(unit: UInt32) -> Bool {
        ViceEnginePreviewDriveSound(unit)
    }

    /// Attaches a tape image.
    @discardableResult
    public func attachTape(unit: UInt32 = 1, url: URL) -> Bool {
        url.path.withCString { path in
            ViceEngineAttachTape(unit, path)
        }
    }

    /// Detaches a tape image.
    @discardableResult
    public func detachTape(unit: UInt32 = 1) -> Bool {
        ViceEngineDetachTape(unit)
    }

    /// Sends a tape deck command.
    @discardableResult
    public func controlTape(unit: UInt32 = 1, command: MacVICETapeCommand) -> Bool {
        ViceEngineControlTape(unit, command.rawValue)
    }

    /// Sends a raw tape deck command value.
    @discardableResult
    public func controlTape(unit: UInt32 = 1, rawCommand: Int32) -> Bool {
        ViceEngineControlTape(unit, rawCommand)
    }

    /// Attaches a cartridge image.
    @discardableResult
    public func attachCartridge(_ url: URL) -> Bool {
        url.path.withCString { path in
            ViceEngineAttachCartridge(path)
        }
    }

    /// Detaches the current cartridge image.
    @discardableResult
    public func detachCartridge() -> Bool {
        ViceEngineDetachCartridge()
    }

    /// Saves a VICE snapshot.
    @discardableResult
    public func saveSnapshot(to url: URL,
                             includesROMs: Bool = false,
                             includesDisks: Bool = true) -> Bool {
        url.path.withCString { path in
            ViceEngineSaveSnapshot(path, includesROMs, includesDisks)
        }
    }

    /// Loads a VICE snapshot.
    @discardableResult
    public func loadSnapshot(from url: URL) -> Bool {
        url.path.withCString { path in
            ViceEngineLoadSnapshot(path)
        }
    }

    /// Encodes the latest video frame as PNG data.
    public func latestScreenshotPNG() throws -> Data {
        try videoSource.latestScreenshotPNG()
    }

    /// Last error message reported by the VICE bridge, if any.
    public static var lastError: String? {
        guard let error = ViceEngineGetLastError() else {
            return nil
        }

        let message = String(cString: error).trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    static var lastErrorMessage: String {
        guard let lastError else {
            return "Unknown VICE engine error."
        }
        return lastError
    }
}

private extension MacVICEDriveStatus {
    init(raw: ViceEngineDriveStatus) {
        self.init(unit: Int(raw.unit),
                  enabled: raw.enabled,
                  driveType: raw.driveType,
                  activeDriveNumber: raw.activeDriveNumber,
                  ledColor: raw.ledColor,
                  ledIntensity: raw.ledIntensity,
                  errorIntensity: raw.errorIntensity,
                  drive0LEDIntensity: raw.drive0LEDIntensity,
                  drive1LEDIntensity: raw.drive1LEDIntensity,
                  track: raw.trackValid ? raw.track : nil,
                  halfTrack: raw.trackValid ? raw.halfTrack : nil,
                  diskSide: raw.diskSide,
                  driveStatusCode: raw.driveStatusCode,
                  driveStatusText: String(macVICECString: raw.driveStatusText),
                  imagePath: String(macVICECString: raw.imagePath),
                  drive0ImagePath: String(macVICECString: raw.drive0ImagePath),
                  drive1ImagePath: String(macVICECString: raw.drive1ImagePath))
    }
}

private extension MacVICECartridgeStatus {
    init(raw: ViceEngineCartridgeStatus) {
        self.init(isAttached: raw.attached,
                  cartridgeID: raw.cartridgeID,
                  cartridgeFlags: raw.cartridgeFlags,
                  romSize: raw.romSize,
                  chipCount: raw.chipCount,
                  bankCount: raw.bankCount,
                  cartridgeName: String(macVICECString: raw.cartridgeName),
                  imagePath: String(macVICECString: raw.imagePath))
    }
}

private extension MacVICEVSIDState {
    init(raw: ViceEngineVSIDState) {
        self.init(name: String(macVICEFixedCString: raw.name, capacity: VICE_ENGINE_VSID_TEXT_CAPACITY),
                  author: String(macVICEFixedCString: raw.author, capacity: VICE_ENGINE_VSID_TEXT_CAPACITY),
                  copyright: String(macVICEFixedCString: raw.copyright, capacity: VICE_ENGINE_VSID_TEXT_CAPACITY),
                  irq: String(macVICEFixedCString: raw.irq, capacity: VICE_ENGINE_VSID_TEXT_CAPACITY),
                  driverInfo: String(macVICEFixedCString: raw.driverInfo, capacity: VICE_ENGINE_VSID_TEXT_CAPACITY),
                  sync: raw.sync,
                  sidModel: raw.sidModel,
                  currentTune: raw.currentTune,
                  tuneCount: raw.tuneCount,
                  defaultTune: raw.defaultTune,
                  deciseconds: raw.deciseconds,
                  driverAddress: raw.driverAddress,
                  loadAddress: raw.loadAddress,
                  initAddress: raw.initAddress,
                  playAddress: raw.playAddress,
                  dataSize: raw.dataSize)
    }
}

private extension MacVICESIDVoiceSamples {
    init(raw: ViceEngineSIDVoiceSamples, samples: Data) {
        let voiceCount = min(Int(raw.voiceCount), Self.voiceCountPerChip)
        self.init(samples: samples,
                  frameCount: Int(raw.frameCount),
                  voiceCount: voiceCount,
                  chipIndex: Int(raw.chipIndex),
                  sampleRate: raw.sampleRate,
                  clockRate: raw.clockRate,
                  frequencies: Self.fixedArray(raw.frequency, count: voiceCount, as: UInt16.self),
                  controls: Self.fixedArray(raw.control, count: voiceCount, as: UInt8.self),
                  sequence: raw.sequence)
    }

    private static func fixedArray<T, U>(_ tuple: T, count: Int, as: U.Type) -> [U] {
        withUnsafeBytes(of: tuple) { rawBuffer in
            Array(rawBuffer.bindMemory(to: U.self).prefix(count))
        }
    }
}

private extension String {
    init?(macVICECString cString: UnsafePointer<CChar>?) {
        guard let cString,
              cString.pointee != 0 else {
            return nil
        }
        self.init(cString: cString)
    }

    init<T>(macVICEFixedCString tuple: T, capacity: UInt32) {
        self = withUnsafePointer(to: tuple) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(capacity)) { cString in
                String(cString: cString)
            }
        }
    }
}

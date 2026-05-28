import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Waveform

@MainActor
final class VSIDSession: ObservableObject {
    struct EngineState: Equatable, Sendable {
        var name = ""
        var author = ""
        var copyright = ""
        var irq = ""
        var driverInfo = ""
        var sync: UInt32 = 0
        var sidModel: Int32 = 0
        var currentTune: UInt32 = 0
        var tuneCount: UInt32 = 0
        var defaultTune: UInt32 = 0
        var deciseconds: UInt32 = 0
        var driverAddress: UInt32 = 0
        var loadAddress: UInt32 = 0
        var initAddress: UInt32 = 0
        var playAddress: UInt32 = 0
        var dataSize: UInt32 = 0

        var elapsed: TimeInterval {
            TimeInterval(deciseconds) / 10.0
        }

        var sidModelName: String {
            switch sidModel {
            case 1:
                return "MOS 6581"
            case 2:
                return "MOS 8580"
            default:
                return "Tune default"
            }
        }
    }

    struct WaveformSnapshot: Equatable, Sendable {
        static let silent = WaveformSnapshot(samples: Array(repeating: 0, count: 384),
                                             bass: 0,
                                             mid: 0,
                                             treble: 0,
                                             rms: 0,
                                             activeKeys: [],
                                             sequence: 0)

        var samples: [Float]
        var bass: Float
        var mid: Float
        var treble: Float
        var rms: Float
        var activeKeys: [Int]
        var sequence: UInt64
    }

    struct VoiceWaveformSnapshot: Identifiable, Equatable, Sendable {
        static func silentSet(chipCount: Int) -> [VoiceWaveformSnapshot] {
            let count = max(1, chipCount)
            return (0..<count).flatMap { chip in
                (0..<3).map { voice in
                    VoiceWaveformSnapshot(chipIndex: chip,
                                          voiceIndex: voice,
                                          samples: Array(repeating: 0, count: 128),
                                          rms: 0,
                                          frequency: 0,
                                          control: 0,
                                          sampleRate: 48_000,
                                          clockRate: 985_248,
                                          sequence: 0)
                }
            }
        }

        var chipIndex: Int
        var voiceIndex: Int
        var samples: [Float]
        var rms: Float
        var frequency: UInt16
        var control: UInt8
        var sampleRate: UInt32
        var clockRate: UInt32
        var sequence: UInt64

        var id: Int {
            chipIndex * 3 + voiceIndex
        }

        var title: String {
            "SID \(chipIndex + 1) V\(voiceIndex + 1)"
        }

        var isActive: Bool {
            (control & 0x01) != 0 || rms > 0.025
        }

        var keyboardKey: Int? {
            guard frequency > 0, clockRate > 0 else {
                return nil
            }

            let cycles = Double(clockRate)
            let hertz = Double(frequency) * cycles / 16_777_216.0
            guard hertz > 0 else {
                return nil
            }

            let midi = 69.0 + 12.0 * log2(hertz / 440.0)
            return min(max(Int(midi.rounded()) - 36, 0), 35)
        }
    }

    @Published var loadedTune: SIDTuneFile?
    @Published var engineState = EngineState()
    @Published var waveform = WaveformSnapshot.silent
    @Published var voiceWaveforms = VoiceWaveformSnapshot.silentSet(chipCount: 1)
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var statusText = "Drop a SID tune or choose Open SID."
    @Published var soundVolume: Int = 80 {
        didSet {
            let clamped = min(max(soundVolume, 0), 100)
            guard soundVolume == clamped else {
                soundVolume = clamped
                return
            }

            if ViceEngineIsRunning() {
                _ = ViceEngineSetIntResource("SoundVolume", Int32(soundVolume))
            }
        }
    }

    private var didStartEngine = false

    var displayTitle: String {
        let viceTitle = engineState.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !viceTitle.isEmpty {
            return viceTitle
        }

        return loadedTune?.displayTitle ?? "VSID"
    }

    var displayAuthor: String {
        let viceAuthor = engineState.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !viceAuthor.isEmpty {
            return viceAuthor
        }

        return loadedTune?.displayAuthor ?? "No tune loaded"
    }

    var tuneCount: Int {
        let viceCount = Int(engineState.tuneCount)
        return max(viceCount, loadedTune?.tuneCount ?? 1)
    }

    var currentTune: Int {
        let viceTune = Int(engineState.currentTune)
        if viceTune > 0 {
            return viceTune
        }

        return loadedTune?.defaultTune ?? 1
    }

    var sidChipCount: Int {
        max(1, min(3, loadedTune?.sidChipCount ?? 1))
    }

    var visibleVoiceWaveforms: [VoiceWaveformSnapshot] {
        let expectedCount = sidChipCount * 3
        if voiceWaveforms.count >= expectedCount {
            return Array(voiceWaveforms.prefix(expectedCount))
        }

        var voices = voiceWaveforms
        let silent = VoiceWaveformSnapshot.silentSet(chipCount: sidChipCount)
        voices.append(contentsOf: silent.dropFirst(voiceWaveforms.count))
        return Array(voices.prefix(expectedCount))
    }

    var activeKeyboardKeys: [Int] {
        let voiceKeys = visibleVoiceWaveforms.compactMap { voice in
            voice.isActive ? voice.keyboardKey : nil
        }

        return voiceKeys.isEmpty ? waveform.activeKeys : Array(Set(voiceKeys)).sorted()
    }

    var canSelectPreviousTune: Bool {
        currentTune > 1
    }

    var canSelectNextTune: Bool {
        currentTune < tuneCount
    }

    func openSIDPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open SID Tune"
        panel.message = "Choose a PSID, RSID, MUS, or STR tune."
        panel.allowedContentTypes = Self.sidContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        openTune(at: url)
    }

    func openTune(at url: URL) {
        do {
            loadedTune = try SIDTuneFile.load(from: url)
            resetVisualizers(chipCount: sidChipCount)
            statusText = "Loaded \(url.lastPathComponent)"
            isPlaying = true
            isPaused = false
            let engineWasStarted = didStartEngine
            startEngineIfNeeded(initialTuneURL: engineWasStarted ? nil : url)
            if engineWasStarted && didStartEngine {
                _ = ViceEngineAutostartMedia(url.path, false)
            }
        } catch {
            statusText = error.localizedDescription
        }
    }

    func startEngineIfNeeded(initialTuneURL: URL? = nil) {
        guard !didStartEngine else {
            return
        }

        guard let executablePath = Bundle.main.executableURL?.path,
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path,
              let runtimeDirectory = Bundle.main.privateFrameworksURL?.path else {
            statusText = "The VSID runtime is missing from the app bundle."
            return
        }

        let dynamicLibraryPath = URL(fileURLWithPath: runtimeDirectory)
            .appendingPathComponent("libvicemacvsid.dylib")
            .path

        var arguments = [
            executablePath,
            "-default",
            "-directory",
            dataDirectory,
            "-sound",
            "-sounddev",
            "coreaudio",
            "-soundrate",
            "48000",
            "-soundbufsize",
            "20",
            "-soundfragsize",
            "0",
            "-soundoutput",
            "0",
            "-sidengine",
            "8",
            "-soundvolume",
            "\(soundVolume)"
        ]
        if let initialTuneURL {
            arguments.append(initialTuneURL.path)
        }

        ViceEngineSetVSIDStateCallback(viceVSIDStateCallback,
                                       Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetAudioSamplesCallback(viceAudioSamplesCallback,
                                          Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetSIDVoiceSamplesCallback(viceSIDVoiceSamplesCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let startResult = "vsid".withCString { machineIDPointer in
            dynamicLibraryPath.withCString { dynamicLibraryPathPointer in
                arguments.withCStringArray { argumentCount, argumentPointers in
                    ViceEngineStartMachine(machineIDPointer,
                                           dynamicLibraryPathPointer,
                                           argumentCount,
                                           argumentPointers)
                }
            }
        }

        if startResult == true || ViceEngineIsRunning() {
            didStartEngine = true
            statusText = initialTuneURL == nil ? "VSID ready" : "Playing \(initialTuneURL?.lastPathComponent ?? "SID")"
        } else if let error = ViceEngineGetLastError() {
            statusText = String(cString: error)
        } else {
            statusText = "Unable to start VSID."
        }
    }

    func playOrResume() {
        if loadedTune == nil {
            openSIDPanel()
            return
        }

        startEngineIfNeeded(initialTuneURL: loadedTune?.url)
        _ = ViceEngineSetPauseEnabled(false)
        isPlaying = true
        isPaused = false
    }

    func pause() {
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetPauseEnabled(true)
        isPaused = true
        isPlaying = false
    }

    func stop() {
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetPauseEnabled(true)
        isPaused = true
        isPlaying = false
        engineState.deciseconds = 0
        resetVisualizers(chipCount: sidChipCount)
    }

    func selectTune(_ tune: Int) {
        let nextTune = min(max(tune, 1), tuneCount)
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetIntResource("PSIDTune", Int32(nextTune))
        _ = ViceEngineTriggerMachineReset(false)
        resetVisualizers(chipCount: sidChipCount)
        isPlaying = true
        isPaused = false
    }

    func selectPreviousTune() {
        selectTune(currentTune - 1)
    }

    func selectNextTune() {
        selectTune(currentTune + 1)
    }

    fileprivate func apply(engineState snapshot: EngineState) {
        engineState = snapshot
    }

    fileprivate func apply(waveform snapshot: WaveformSnapshot) {
        var displaySnapshot = snapshot
        displaySnapshot.samples = VSIDScopeSignal.oscilloscope(samples: snapshot.samples,
                                                               targetCount: 384,
                                                               targetPeak: 0.80,
                                                               maxGain: 26,
                                                               silenceThreshold: 0.0007)
        waveform = displaySnapshot
    }

    fileprivate func apply(voiceWaveforms snapshots: [VoiceWaveformSnapshot], chipIndex: Int) {
        let chipCount = max(sidChipCount, chipIndex + 1)
        let expectedCount = chipCount * 3
        var voices = voiceWaveforms

        if voices.count < expectedCount {
            let silent = VoiceWaveformSnapshot.silentSet(chipCount: chipCount)
            voices.append(contentsOf: silent.dropFirst(voices.count))
        }

        for snapshot in snapshots {
            let index = snapshot.id
            guard index >= 0 && index < voices.count else {
                continue
            }

            var displaySnapshot = snapshot
            let displaySamples = VSIDScopeSignal.oscilloscope(samples: snapshot.samples,
                                                              targetCount: 128,
                                                              targetPeak: 0.86,
                                                              maxGain: 512,
                                                              silenceThreshold: 0.000001)
            displaySnapshot.samples = displaySamples
            displaySnapshot.rms = max(snapshot.rms, VSIDScopeSignal.rms(displaySamples) * 0.65)
            voices[index] = displaySnapshot
        }

        voiceWaveforms = voices
    }

    private func resetVisualizers(chipCount: Int) {
        waveform = .silent
        voiceWaveforms = VoiceWaveformSnapshot.silentSet(chipCount: chipCount)
    }

    private static let sidContentTypes: [UTType] = {
        var types: [UTType] = [.data]
        for extensionValue in ["sid", "mus", "str"] {
            if let type = UTType(filenameExtension: extensionValue) {
                types.append(type)
            }
        }
        return types
    }()
}

private func viceVSIDStateCallback(_ state: UnsafePointer<ViceEngineVSIDState>?,
                                   _ context: UnsafeMutableRawPointer?) {
    guard let state,
          let context else {
        return
    }

    let snapshot = VSIDSession.EngineState(viceState: state.pointee)
    let session = Unmanaged<VSIDSession>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor [session, snapshot] in
        session.apply(engineState: snapshot)
    }
}

private func viceAudioSamplesCallback(_ samples: UnsafePointer<ViceEngineAudioSamples>?,
                                      _ context: UnsafeMutableRawPointer?) {
    guard let samples,
          let context,
          let samplePointer = samples.pointee.samples else {
        return
    }

    let snapshot = VSIDSession.WaveformSnapshot(audioSamples: samples.pointee,
                                                samplePointer: samplePointer)
    let session = Unmanaged<VSIDSession>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor [session, snapshot] in
        session.apply(waveform: snapshot)
    }
}

private func viceSIDVoiceSamplesCallback(_ samples: UnsafePointer<ViceEngineSIDVoiceSamples>?,
                                         _ context: UnsafeMutableRawPointer?) {
    guard let samples,
          let context,
          let samplePointer = samples.pointee.samples else {
        return
    }

    let snapshots = VSIDSession.VoiceWaveformSnapshot.snapshots(voiceSamples: samples.pointee,
                                                                samplePointer: samplePointer)
    let chipIndex = Int(samples.pointee.chipIndex)
    let session = Unmanaged<VSIDSession>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor [session, snapshots, chipIndex] in
        session.apply(voiceWaveforms: snapshots, chipIndex: chipIndex)
    }
}

private enum VSIDScopeSignal {
    static func oscilloscope(samples: [Float],
                             targetCount: Int,
                             targetPeak: Float,
                             maxGain: Float,
                             silenceThreshold: Float) -> [Float] {
        guard targetCount > 0 else {
            return []
        }

        guard !samples.isEmpty else {
            return Array(repeating: 0, count: targetCount)
        }

        let mean = samples.reduce(Float(0), +) / Float(samples.count)
        let acCoupled = samples.map { $0 - mean }
        let peak = acCoupled.reduce(Float(0)) { max($0, abs($1)) }

        guard peak > silenceThreshold else {
            return Array(repeating: 0, count: targetCount)
        }

        let triggered = triggeredWindow(acCoupled)
        let resampled = resample(triggered, targetCount: targetCount)
        let gain = min(maxGain, targetPeak / peak)
        return resampled.map { min(max($0 * gain, -1), 1) }
    }

    static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let squared = samples.reduce(Float(0)) { partial, sample in
            partial + sample * sample
        }
        return min(max(sqrt(squared / Float(samples.count)), 0), 1)
    }

    static func resampledForDisplay(_ samples: [Float], targetCount: Int) -> [Float] {
        resample(samples, targetCount: targetCount)
    }

    private static func triggeredWindow(_ samples: [Float]) -> [Float] {
        guard samples.count > 2 else {
            return samples
        }

        let triggerIndex = samples.indices.dropFirst().first { index in
            samples[index - 1] <= 0 && samples[index] > 0
        } ?? samples.indices.max { abs(samples[$0]) < abs(samples[$1]) } ?? samples.startIndex

        guard triggerIndex > samples.startIndex else {
            return samples
        }

        return Array(samples[triggerIndex...]) + Array(samples[..<triggerIndex])
    }

    private static func resample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 0 else {
            return []
        }

        guard samples.count > 1 else {
            return Array(repeating: samples.first ?? 0, count: targetCount)
        }

        if samples.count == targetCount {
            return samples
        }

        return (0..<targetCount).map { index in
            let position = Float(index) * Float(samples.count - 1) / Float(max(1, targetCount - 1))
            let lower = Int(position.rounded(.down))
            let upper = min(samples.count - 1, lower + 1)
            let fraction = position - Float(lower)
            return samples[lower] + (samples[upper] - samples[lower]) * fraction
        }
    }
}

private extension VSIDSession.WaveformSnapshot {
    init(audioSamples: ViceEngineAudioSamples, samplePointer: UnsafePointer<Int16>) {
        let frameCount = max(0, Int(audioSamples.frameCount))
        let channelCount = max(1, Int(audioSamples.channelCount))
        let rawSampleCount = frameCount * channelCount

        guard frameCount > 0, rawSampleCount > 0 else {
            self = .silent
            return
        }

        let rawSamples = UnsafeBufferPointer(start: samplePointer, count: rawSampleCount)
        let targetCount = 384
        let bucketSize = max(1, frameCount / targetCount)
        var waveformSamples: [Float] = []
        waveformSamples.reserveCapacity(targetCount)

        var lowpass: Float = 0
        var previous: Float = 0
        var bassEnergy: Float = 0
        var midEnergy: Float = 0
        var trebleEnergy: Float = 0
        var squaredEnergy: Float = 0
        var zeroCrossings = 0

        for bucketStart in stride(from: 0, to: frameCount, by: bucketSize) {
            let bucketEnd = min(frameCount, bucketStart + bucketSize)
            var peak: Float = 0

            for frame in bucketStart..<bucketEnd {
                let sample = Self.monoSample(rawSamples: rawSamples,
                                             frame: frame,
                                             channelCount: channelCount)
                let absSample = abs(sample)
                if absSample > abs(peak) {
                    peak = sample
                }

                lowpass = lowpass * 0.92 + sample * 0.08
                let mid = sample - lowpass
                let treble = sample - previous
                bassEnergy += abs(lowpass)
                midEnergy += abs(mid)
                trebleEnergy += abs(treble)
                squaredEnergy += sample * sample
                if (previous < 0 && sample >= 0) || (previous > 0 && sample <= 0) {
                    zeroCrossings += 1
                }
                previous = sample
            }

            waveformSamples.append(peak)
            if waveformSamples.count == targetCount {
                break
            }
        }

        let frames = max(1, frameCount)
        let bass = Self.clamp01((bassEnergy / Float(frames)) * 4.8)
        let mid = Self.clamp01((midEnergy / Float(frames)) * 5.8)
        let treble = Self.clamp01((trebleEnergy / Float(frames)) * 3.3)
        let rms = Self.clamp01(sqrt(squaredEnergy / Float(frames)) * 3.8)
        let key = Self.estimatedKeyboardKey(zeroCrossings: zeroCrossings,
                                            frameCount: frameCount,
                                            sampleRate: Int(audioSamples.sampleRate))

        self.init(samples: waveformSamples,
                  bass: bass,
                  mid: mid,
                  treble: treble,
                  rms: rms,
                  activeKeys: Self.activeKeys(baseKey: key, bass: bass, mid: mid, treble: treble),
                  sequence: audioSamples.sequence)
    }

    private static func monoSample(rawSamples: UnsafeBufferPointer<Int16>,
                                   frame: Int,
                                   channelCount: Int) -> Float {
        let base = frame * channelCount
        var mixed: Int = 0
        for channel in 0..<channelCount {
            mixed += Int(rawSamples[base + channel])
        }
        return Float(mixed) / Float(channelCount) / 32768.0
    }

    private static func estimatedKeyboardKey(zeroCrossings: Int,
                                             frameCount: Int,
                                             sampleRate: Int) -> Int {
        guard zeroCrossings > 1, frameCount > 0, sampleRate > 0 else {
            return 12
        }

        let frequency = (Float(zeroCrossings) * Float(sampleRate)) / (Float(frameCount) * 2.0)
        guard frequency > 0 else {
            return 12
        }

        let midi = 69.0 + 12.0 * log2(Double(frequency) / 440.0)
        let note = ((Int(midi.rounded()) % 12) + 12) % 12
        return 12 + note
    }

    private static func activeKeys(baseKey: Int, bass: Float, mid: Float, treble: Float) -> [Int] {
        let root = min(max(baseKey, 0), 35)
        var keys = [root]
        if bass > 0.18 {
            keys.append(max(0, root - 12))
        }
        if mid > 0.16 {
            keys.append(min(35, root + 7))
        }
        if treble > 0.14 {
            keys.append(min(35, root + 12))
        }
        return Array(Set(keys)).sorted()
    }

    private static func clamp01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

private extension VSIDSession.VoiceWaveformSnapshot {
    static func snapshots(voiceSamples: ViceEngineSIDVoiceSamples,
                          samplePointer: UnsafePointer<Int16>) -> [VSIDSession.VoiceWaveformSnapshot] {
        let frameCount = max(0, Int(voiceSamples.frameCount))
        let voiceCount = max(1, min(Int(voiceSamples.voiceCount), Int(VICE_ENGINE_SID_VOICE_COUNT)))
        let rawSampleCount = frameCount * voiceCount

        guard frameCount > 0, rawSampleCount > 0 else {
            return []
        }

        let rawSamples = UnsafeBufferPointer(start: samplePointer, count: rawSampleCount)
        let frequencies = Self.fixedArray(voiceSamples.frequency, count: voiceCount, as: UInt16.self)
        let controls = Self.fixedArray(voiceSamples.control, count: voiceCount, as: UInt8.self)

        return (0..<voiceCount).map { voice in
            let samples = Self.downsample(rawSamples: rawSamples,
                                          frameCount: frameCount,
                                          voiceCount: voiceCount,
                                          voiceIndex: voice)
            let rms = Self.rms(rawSamples: rawSamples,
                               frameCount: frameCount,
                               voiceCount: voiceCount,
                               voiceIndex: voice)
            return VSIDSession.VoiceWaveformSnapshot(chipIndex: Int(voiceSamples.chipIndex),
                                                     voiceIndex: voice,
                                                     samples: samples,
                                                     rms: rms,
                                                     frequency: frequencies[safe: voice] ?? 0,
                                                     control: controls[safe: voice] ?? 0,
                                                     sampleRate: voiceSamples.sampleRate,
                                                     clockRate: voiceSamples.clockRate,
                                                     sequence: voiceSamples.sequence)
        }
    }

    private static func downsample(rawSamples: UnsafeBufferPointer<Int16>,
                                   frameCount: Int,
                                   voiceCount: Int,
                                   voiceIndex: Int) -> [Float] {
        var output: [Float] = []
        output.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            output.append(Float(rawSamples[(frame * voiceCount) + voiceIndex]) / 32768.0)
        }

        return output
    }

    private static func rms(rawSamples: UnsafeBufferPointer<Int16>,
                            frameCount: Int,
                            voiceCount: Int,
                            voiceIndex: Int) -> Float {
        guard frameCount > 0 else {
            return 0
        }

        var squared: Float = 0
        for frame in 0..<frameCount {
            let sample = Float(rawSamples[(frame * voiceCount) + voiceIndex]) / 32768.0
            squared += sample * sample
        }

        return min(max(sqrt(squared / Float(frameCount)) * 3.8, 0), 1)
    }

    private static func fixedArray<T, U>(_ tuple: T, count: Int, as: U.Type) -> [U] {
        withUnsafeBytes(of: tuple) { rawBuffer in
            Array(rawBuffer.bindMemory(to: U.self).prefix(count))
        }
    }
}

private extension VSIDSession.EngineState {
    init(viceState: ViceEngineVSIDState) {
        self.name = Self.string(from: viceState.name)
        self.author = Self.string(from: viceState.author)
        self.copyright = Self.string(from: viceState.copyright)
        self.irq = Self.string(from: viceState.irq)
        self.driverInfo = Self.string(from: viceState.driverInfo)
        self.sync = viceState.sync
        self.sidModel = viceState.sidModel
        self.currentTune = viceState.currentTune
        self.tuneCount = viceState.tuneCount
        self.defaultTune = viceState.defaultTune
        self.deciseconds = viceState.deciseconds
        self.driverAddress = viceState.driverAddress
        self.loadAddress = viceState.loadAddress
        self.initAddress = viceState.initAddress
        self.playAddress = viceState.playAddress
        self.dataSize = viceState.dataSize
    }

    private static func string<T>(from tuple: T) -> String {
        withUnsafePointer(to: tuple) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: Int(VICE_ENGINE_VSID_TEXT_CAPACITY)) { cString in
                String(cString: cString)
            }
        }
    }
}

struct VSIDPlayerView: View {
    @EnvironmentObject private var session: VSIDSession

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VSIDStageView()
                    .environmentObject(session)
                    .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VSIDInspectorView()
                    .environmentObject(session)
                    .frame(width: 324)
            }

            Divider()

            VSIDTransportBar()
                .environmentObject(session)
        }
        .frame(minWidth: 920, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else {
                return false
            }

            session.openTune(at: url)
            return true
        }
    }
}

private struct VSIDStageView: View {
    @EnvironmentObject private var session: VSIDSession

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(session.displayAuthor)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatElapsed(session.engineState.elapsed))
                        .font(.system(.title2, design: .monospaced, weight: .semibold))
                        .monospacedDigit()
                    Text("Tune \(session.currentTune) of \(session.tuneCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 14) {
                VStack(spacing: 12) {
                    VSIDScopeView(isActive: session.isPlaying && !session.isPaused,
                                  waveform: session.waveform,
                                  voices: session.visibleVoiceWaveforms,
                                  elapsed: session.engineState.elapsed)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.05, contentMode: .fit)

                    VSIDVoiceScopeMatrixView(voices: session.visibleVoiceWaveforms,
                                             chipCount: session.sidChipCount)
                        .frame(height: voiceMatrixHeight)
                }

                VSIDBandView(waveform: session.waveform,
                             isActive: session.isPlaying && !session.isPaused)
                    .frame(width: 214)
                    .aspectRatio(1.08, contentMode: .fit)
            }

            VSIDKeyboardView(waveform: session.waveform,
                             activeKeys: session.activeKeyboardKeys)
                .frame(height: 82)

            HStack(spacing: 10) {
                VSIDStatusChip(title: session.loadedTune?.format.rawValue ?? "SID",
                               systemImage: "music.note")
                VSIDStatusChip(title: session.engineState.sidModelName,
                               systemImage: "waveform")
                VSIDStatusChip(title: session.loadedTune?.clockName ?? "Clock",
                               systemImage: "metronome")
                if let secondSID = session.loadedTune?.secondSIDAddress {
                    VSIDStatusChip(title: "2SID \(hex(secondSID))",
                                   systemImage: "speaker.wave.2")
                }
                if let thirdSID = session.loadedTune?.thirdSIDAddress {
                    VSIDStatusChip(title: "3SID \(hex(thirdSID))",
                                   systemImage: "speaker.wave.3")
                }
                Spacer()
            }
        }
        .padding(28)
    }

    private var voiceMatrixHeight: CGFloat {
        CGFloat(session.sidChipCount * 46 + max(0, session.sidChipCount - 1) * 8)
    }
}

private struct VSIDWaveformTraceView: View {
    let samples: [Float]
    let color: Color
    let opacity: Double

    var body: some View {
        Waveform(samples: SampleBuffer(samples: displaySamples))
            .foregroundColor(color.opacity(opacity))
            .allowsHitTesting(false)
    }

    private var displaySamples: [Float] {
        samples.isEmpty ? [0] : samples
    }
}

private struct VSIDScopeView: View {
    let isActive: Bool
    let waveform: VSIDSession.WaveformSnapshot
    let voices: [VSIDSession.VoiceWaveformSnapshot]
    let elapsed: TimeInterval

    var body: some View {
        TimelineView(.animation) { timeline in
            ZStack {
                Canvas { context, size in
                    drawGrid(in: context, size: size)
                    drawLevelTrace(in: context,
                                   size: size,
                                   time: timeline.date.timeIntervalSinceReferenceDate)
                }

                if activeVoiceTraces.isEmpty {
                    VSIDWaveformTraceView(samples: waveform.samples,
                                          color: Color(red: 0.18, green: 0.90, blue: 0.96),
                                          opacity: isActive ? 0.92 : 0.34)
                } else {
                    ForEach(activeVoiceTraces) { trace in
                        VSIDWaveformTraceView(samples: VSIDScopeSignal.resampledForDisplay(trace.samples,
                                                                                           targetCount: 384),
                                              color: traceColor(for: trace),
                                              opacity: activeVoiceTraces.count > 3 ? 0.62 : 0.82)
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.48))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .accessibilityLabel("SID signal visualizer")
    }

    private var activeVoiceTraces: [VSIDSession.VoiceWaveformSnapshot] {
        voices.filter { $0.samples.count > 1 && ($0.isActive || VSIDScopeSignal.rms($0.samples) > 0.015) }
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize) {
        var path = Path()
        let columns = 16
        let rows = 10
        for column in 0...columns {
            let x = size.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for row in 0...rows {
            let y = size.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(.white.opacity(0.055)), lineWidth: 1)
    }

    private func drawWaveform(in context: GraphicsContext, size: CGSize) {
        guard waveform.samples.count > 1 else {
            return
        }

        var glowPath = Path()
        var tracePath = Path()
        let centerY = size.height * 0.5
        let gain = size.height * 0.42 * CGFloat(isActive ? 1.0 : 0.35)

        for index in waveform.samples.indices {
            let progress = CGFloat(index) / CGFloat(max(1, waveform.samples.count - 1))
            let x = progress * size.width
            let y = centerY - CGFloat(waveform.samples[index]) * gain
            if index == 0 {
                glowPath.move(to: CGPoint(x: x, y: y))
                tracePath.move(to: CGPoint(x: x, y: y))
            } else {
                glowPath.addLine(to: CGPoint(x: x, y: y))
                tracePath.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(glowPath,
                       with: .color(Color(red: 0.13, green: 0.86, blue: 0.95).opacity(0.18)),
                       lineWidth: 7)
        context.stroke(tracePath,
                       with: .color(Color(red: 0.18, green: 0.90, blue: 0.96).opacity(isActive ? 0.96 : 0.38)),
                       lineWidth: 2.2)
    }

    private func drawVoiceWaveforms(in context: GraphicsContext, size: CGSize) {
        let activeVoices = voices.filter { $0.samples.count > 1 && ($0.isActive || VSIDScopeSignal.rms($0.samples) > 0.015) }
        guard !activeVoices.isEmpty else {
            return
        }

        for voice in activeVoices {
            drawTrace(samples: VSIDScopeSignal.resampledForDisplay(voice.samples, targetCount: 384),
                      color: traceColor(for: voice),
                      opacity: activeVoices.count > 3 ? 0.70 : 0.90,
                      lineWidth: activeVoices.count > 3 ? 1.4 : 1.8,
                      in: context,
                      size: size)
        }
    }

    private func drawTrace(samples: [Float],
                           color: Color,
                           opacity: Double,
                           lineWidth: CGFloat,
                           in context: GraphicsContext,
                           size: CGSize) {
        guard samples.count > 1 else {
            return
        }

        var trace = Path()
        let centerY = size.height * 0.5
        let gain = size.height * 0.42

        for index in samples.indices {
            let progress = CGFloat(index) / CGFloat(max(1, samples.count - 1))
            let x = progress * size.width
            let y = centerY - CGFloat(samples[index]) * gain
            if index == 0 {
                trace.move(to: CGPoint(x: x, y: y))
            } else {
                trace.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(trace,
                       with: .color(color.opacity(opacity)),
                       lineWidth: lineWidth)
    }

    private func traceColor(for voice: VSIDSession.VoiceWaveformSnapshot) -> Color {
        let palette = [
            Color(red: 0.20, green: 0.86, blue: 0.96),
            Color(red: 0.96, green: 0.60, blue: 0.24),
            Color(red: 0.68, green: 0.86, blue: 0.32)
        ]
        return palette[voice.voiceIndex % palette.count]
    }

    private func drawLevelTrace(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let levels = [waveform.bass, waveform.mid, waveform.treble]
        let colors = [
            Color(red: 0.68, green: 0.86, blue: 0.32),
            Color(red: 1.0, green: 0.62, blue: 0.25),
            Color(red: 0.95, green: 0.25, blue: 0.34)
        ]
        let width: CGFloat = 7
        let gap: CGFloat = 5
        let startX = size.width - CGFloat(levels.count) * width - CGFloat(levels.count - 1) * gap - 12
        let floorY = size.height - 12

        for index in levels.indices {
            let pulse = 0.88 + 0.12 * sin(time * 5.0 + Double(index))
            let levelHeight = size.height * 0.42 * CGFloat(levels[index]) * CGFloat(pulse)
            let rect = CGRect(x: startX + CGFloat(index) * (width + gap),
                              y: floorY - levelHeight,
                              width: width,
                              height: max(3, levelHeight))
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(colors[index].opacity(0.86)))
        }
    }

}

private struct VSIDBandView: View {
    let waveform: VSIDSession.WaveformSnapshot
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                drawBackdrop(in: context, size: size)
                drawDrummer(in: context, size: size, time: time)
                drawBassist(in: context, size: size, time: time)
                drawKeyboardist(in: context, size: size, time: time)
                drawLEDs(in: context, size: size)
            }
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.40))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }
        }
        .accessibilityLabel("Animated SID band")
    }

    private var motionScale: CGFloat {
        isActive ? 1 : 0.18
    }

    private func drawBackdrop(in context: GraphicsContext, size: CGSize) {
        let floor = CGRect(x: 0, y: size.height * 0.68, width: size.width, height: size.height * 0.32)
        context.fill(Path(floor), with: .color(Color(red: 0.10, green: 0.12, blue: 0.12).opacity(0.82)))

        var horizon = Path()
        horizon.move(to: CGPoint(x: 0, y: size.height * 0.68))
        horizon.addLine(to: CGPoint(x: size.width, y: size.height * 0.68))
        context.stroke(horizon, with: .color(.white.opacity(0.10)), lineWidth: 1)
    }

    private func drawDrummer(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let energy = CGFloat(waveform.bass) * motionScale
        let beat = CGFloat(max(0, sin(time * 10.0))) * energy
        let origin = CGPoint(x: size.width * 0.23, y: size.height * 0.63 - beat * 8)

        drawSpriteBody(in: context,
                       origin: origin,
                       shirt: Color(red: 0.70, green: 0.86, blue: 0.32),
                       bob: beat * 4)

        let drum = CGRect(x: origin.x - 24, y: origin.y + 17, width: 48, height: 25)
        context.fill(Path(ellipseIn: drum), with: .color(Color(red: 0.13, green: 0.70, blue: 0.78).opacity(0.88)))
        context.stroke(Path(ellipseIn: drum), with: .color(.white.opacity(0.18)), lineWidth: 1)

        var leftStick = Path()
        leftStick.move(to: CGPoint(x: origin.x - 9, y: origin.y + 5))
        leftStick.addLine(to: CGPoint(x: origin.x - 28, y: origin.y - 7 - beat * 12))
        var rightStick = Path()
        rightStick.move(to: CGPoint(x: origin.x + 9, y: origin.y + 5))
        rightStick.addLine(to: CGPoint(x: origin.x + 28, y: origin.y - 3 - beat * 10))
        context.stroke(leftStick, with: .color(Color(red: 0.90, green: 0.78, blue: 0.52)), lineWidth: 2)
        context.stroke(rightStick, with: .color(Color(red: 0.90, green: 0.78, blue: 0.52)), lineWidth: 2)
    }

    private func drawBassist(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let energy = CGFloat(waveform.mid) * motionScale
        let sway = CGFloat(sin(time * 4.6)) * energy * 9
        let origin = CGPoint(x: size.width * 0.52 + sway, y: size.height * 0.58)

        drawSpriteBody(in: context,
                       origin: origin,
                       shirt: Color(red: 1.0, green: 0.52, blue: 0.26),
                       bob: abs(sway) * 0.24)

        var neck = Path()
        neck.move(to: CGPoint(x: origin.x + 2, y: origin.y + 12))
        neck.addLine(to: CGPoint(x: origin.x + 48, y: origin.y - 18))
        context.stroke(neck, with: .color(Color(red: 0.80, green: 0.58, blue: 0.34)), lineWidth: 4)
        context.fill(Path(ellipseIn: CGRect(x: origin.x - 8, y: origin.y + 7, width: 38, height: 20)),
                     with: .color(Color(red: 0.96, green: 0.34, blue: 0.34).opacity(0.88)))
        context.stroke(neck, with: .color(.white.opacity(0.16)), lineWidth: 1)
    }

    private func drawKeyboardist(in context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let energy = CGFloat(waveform.treble) * motionScale
        let bounce = CGFloat(max(0, sin(time * 7.2 + 0.8))) * energy * 8
        let origin = CGPoint(x: size.width * 0.78, y: size.height * 0.59 - bounce)

        drawSpriteBody(in: context,
                       origin: origin,
                       shirt: Color(red: 0.20, green: 0.72, blue: 0.92),
                       bob: bounce)

        let keyboard = CGRect(x: origin.x - 34, y: origin.y + 22, width: 68, height: 14)
        context.fill(Path(roundedRect: keyboard, cornerRadius: 3), with: .color(Color(red: 0.88, green: 0.86, blue: 0.78)))
        for key in 0..<9 {
            let x = keyboard.minX + CGFloat(key) * keyboard.width / 9.0
            var keyLine = Path()
            keyLine.move(to: CGPoint(x: x, y: keyboard.minY))
            keyLine.addLine(to: CGPoint(x: x, y: keyboard.maxY))
            context.stroke(keyLine, with: .color(.black.opacity(0.28)), lineWidth: 0.8)
        }
    }

    private func drawLEDs(in context: GraphicsContext, size: CGSize) {
        let levels = [waveform.bass, waveform.mid, waveform.treble, waveform.rms]
        let colors = [
            Color(red: 0.68, green: 0.86, blue: 0.32),
            Color(red: 1.0, green: 0.62, blue: 0.25),
            Color(red: 0.18, green: 0.90, blue: 0.96),
            Color(red: 0.95, green: 0.25, blue: 0.34)
        ]

        for index in levels.indices {
            let rect = CGRect(x: 14 + CGFloat(index) * 14, y: 12, width: 7, height: 7)
            context.fill(Path(ellipseIn: rect), with: .color(colors[index].opacity(Double(0.24 + levels[index] * 0.76))))
        }
    }

    private func drawSpriteBody(in context: GraphicsContext,
                                origin: CGPoint,
                                shirt: Color,
                                bob: CGFloat) {
        let skin = Color(red: 0.86, green: 0.70, blue: 0.54)
        let pants = Color(red: 0.16, green: 0.18, blue: 0.20)
        context.fill(Path(ellipseIn: CGRect(x: origin.x - 10, y: origin.y - 28 - bob, width: 20, height: 20)),
                     with: .color(skin))
        context.fill(Path(roundedRect: CGRect(x: origin.x - 12, y: origin.y - 8 - bob, width: 24, height: 26),
                          cornerRadius: 4),
                     with: .color(shirt.opacity(0.92)))
        context.fill(Path(CGRect(x: origin.x - 11, y: origin.y + 18 - bob, width: 8, height: 20)),
                     with: .color(pants))
        context.fill(Path(CGRect(x: origin.x + 3, y: origin.y + 18 - bob, width: 8, height: 20)),
                     with: .color(pants))
        context.fill(Path(CGRect(x: origin.x - 12, y: origin.y + 37 - bob, width: 11, height: 4)),
                     with: .color(.white.opacity(0.72)))
        context.fill(Path(CGRect(x: origin.x + 3, y: origin.y + 37 - bob, width: 11, height: 4)),
                     with: .color(.white.opacity(0.72)))
    }
}

private struct VSIDVoiceScopeMatrixView: View {
    let voices: [VSIDSession.VoiceWaveformSnapshot]
    let chipCount: Int

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(voices) { voice in
                VSIDVoiceScopeCell(voice: voice)
                    .frame(height: 46)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.30))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .accessibilityLabel("\(chipCount) SID voice scopes")
    }
}

private struct VSIDVoiceScopeCell: View {
    let voice: VSIDSession.VoiceWaveformSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Text("S\(voice.chipIndex + 1) V\(voice.voiceIndex + 1)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(voice.isActive ? traceColor : .secondary)
                .frame(width: 42, alignment: .leading)

            ZStack {
                Canvas { context, size in
                    drawFloor(in: context, size: size)
                }

                VSIDWaveformTraceView(samples: voice.samples,
                                      color: traceColor,
                                      opacity: voice.isActive ? 0.86 : 0.26)
            }
        }
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(voice.isActive ? 0.055 : 0.028))
        }
    }

    private var traceColor: Color {
        let palette = [
            Color(red: 0.20, green: 0.86, blue: 0.96),
            Color(red: 0.96, green: 0.60, blue: 0.24),
            Color(red: 0.68, green: 0.86, blue: 0.32)
        ]
        return palette[voice.voiceIndex % palette.count]
    }

    private func drawFloor(in context: GraphicsContext, size: CGSize) {
        var center = Path()
        center.move(to: CGPoint(x: 0, y: size.height * 0.56))
        center.addLine(to: CGPoint(x: size.width, y: size.height * 0.56))
        context.stroke(center, with: .color(.white.opacity(0.075)), lineWidth: 1)
    }

    private func drawWave(in context: GraphicsContext, size: CGSize) {
        guard voice.samples.count > 1 else {
            return
        }

        var glow = Path()
        var trace = Path()
        let labelReserve: CGFloat = 46
        let width = max(1, size.width - labelReserve)
        let originX = labelReserve
        let centerY = size.height * 0.56
        let gain = size.height * CGFloat(0.34 + voice.rms * 0.26)

        for index in voice.samples.indices {
            let progress = CGFloat(index) / CGFloat(max(1, voice.samples.count - 1))
            let x = originX + progress * width
            let y = centerY - CGFloat(voice.samples[index]) * gain
            if index == 0 {
                glow.move(to: CGPoint(x: x, y: y))
                trace.move(to: CGPoint(x: x, y: y))
            } else {
                glow.addLine(to: CGPoint(x: x, y: y))
                trace.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(glow,
                       with: .color(traceColor.opacity(voice.isActive ? 0.20 : 0.06)),
                       lineWidth: 5)
        context.stroke(trace,
                       with: .color(traceColor.opacity(voice.isActive ? 0.96 : 0.22)),
                       lineWidth: 1.6)
    }

    private func drawLabel(in context: GraphicsContext, size: CGSize) {
        let text = Text("S\(voice.chipIndex + 1) V\(voice.voiceIndex + 1)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(voice.isActive ? traceColor : .secondary)
        context.draw(text, at: CGPoint(x: 10, y: size.height * 0.5), anchor: .leading)
    }
}

private struct VSIDKeyboardView: View {
    let waveform: VSIDSession.WaveformSnapshot
    let activeKeys: [Int]

    var body: some View {
        Canvas { context, size in
            drawWhiteKeys(in: context, size: size)
            drawBlackKeys(in: context, size: size)
        }
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.28))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .accessibilityLabel("SID piano keyboard")
    }

    private func drawWhiteKeys(in context: GraphicsContext, size: CGSize) {
        let whiteNotes = (0..<36).filter { !isBlackPianoKey($0) }
        let activeKeys = Set(activeKeys)
        let keyWidth = size.width / CGFloat(whiteNotes.count)
        let inset: CGFloat = 8
        let height = size.height - inset * 2

        for (index, note) in whiteNotes.enumerated() {
            let rect = CGRect(x: CGFloat(index) * keyWidth + 2,
                              y: inset,
                              width: keyWidth - 3,
                              height: height)
            let active = activeKeys.contains(note)
            let fill = active
                ? Color(red: 0.96, green: 0.63, blue: 0.24).opacity(Double(0.45 + waveform.rms * 0.45))
                : Color(red: 0.88, green: 0.86, blue: 0.78)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(fill))
            context.stroke(Path(roundedRect: rect, cornerRadius: 4),
                           with: .color(.black.opacity(0.22)),
                           lineWidth: 1)
        }
    }

    private func drawBlackKeys(in context: GraphicsContext, size: CGSize) {
        let activeKeys = Set(activeKeys)
        let whiteCount = (0..<36).filter { !isBlackPianoKey($0) }.count
        let whiteWidth = size.width / CGFloat(whiteCount)
        let keyWidth = whiteWidth * 0.58
        let keyHeight = (size.height - 16) * 0.60

        for note in 0..<36 where isBlackPianoKey(note) {
            let whiteIndex = whiteKeyCount(beforeOrAt: note)
            let rect = CGRect(x: CGFloat(whiteIndex) * whiteWidth - keyWidth * 0.5,
                              y: 8,
                              width: keyWidth,
                              height: keyHeight)
            let active = activeKeys.contains(note)
            let fill = active
                ? Color(red: 0.16, green: 0.86, blue: 0.95).opacity(Double(0.50 + waveform.treble * 0.42))
                : Color(red: 0.05, green: 0.06, blue: 0.07)
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(fill))
            context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                           with: .color(.white.opacity(active ? 0.28 : 0.08)),
                           lineWidth: 1)
        }
    }
}

private struct VSIDInspectorView: View {
    @EnvironmentObject private var session: VSIDSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SID Details")
                    .font(.title3.weight(.semibold))
                Text(session.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VSIDMetadataGroup(title: "Tune") {
                VSIDMetadataRow(label: "Title", value: session.displayTitle)
                VSIDMetadataRow(label: "Composer", value: session.displayAuthor)
                VSIDMetadataRow(label: "Released", value: firstNonEmpty(session.engineState.copyright, session.loadedTune?.released))
                VSIDMetadataRow(label: "Format", value: session.loadedTune?.format.rawValue ?? "-")
                VSIDMetadataRow(label: "Compatibility", value: session.loadedTune?.compatibilityName ?? "-")
            }

            VSIDMetadataGroup(title: "Player") {
                VSIDMetadataRow(label: "IRQ", value: firstNonEmpty(session.engineState.irq, "-"))
                VSIDMetadataRow(label: "Load", value: address(session.engineState.loadAddress, fallback: session.loadedTune?.loadAddress))
                VSIDMetadataRow(label: "Init", value: address(session.engineState.initAddress, fallback: session.loadedTune?.initAddress))
                VSIDMetadataRow(label: "Play", value: address(session.engineState.playAddress, fallback: session.loadedTune?.playAddress))
                VSIDMetadataRow(label: "Driver", value: address(session.engineState.driverAddress, fallback: nil))
                VSIDMetadataRow(label: "Size", value: byteCount(Int(session.engineState.dataSize == 0 ? UInt32(session.loadedTune?.dataSize ?? 0) : session.engineState.dataSize)))
            }

            Spacer()
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.58))
    }
}

private struct VSIDTransportBar: View {
    @EnvironmentObject private var session: VSIDSession

    var body: some View {
        HStack(spacing: 14) {
            Button {
                session.openSIDPanel()
            } label: {
                Label("Open", systemImage: "folder")
            }

            Divider()
                .frame(height: 24)

            Button {
                session.selectPreviousTune()
            } label: {
                Image(systemName: "backward.end.fill")
            }
            .disabled(!session.canSelectPreviousTune)
            .help("Previous tune")

            Button {
                session.isPlaying ? session.pause() : session.playOrResume()
            } label: {
                Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 18)
            }
            .keyboardShortcut(.space, modifiers: [])
            .help(session.isPlaying ? "Pause" : "Play")

            Button {
                session.stop()
            } label: {
                Image(systemName: "stop.fill")
            }
            .disabled(session.loadedTune == nil)
            .help("Stop")

            Button {
                session.selectNextTune()
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .disabled(!session.canSelectNextTune)
            .help("Next tune")

            Stepper("Tune \(session.currentTune)", value: Binding {
                session.currentTune
            } set: { tune in
                session.selectTune(tune)
            }, in: 1...max(1, session.tuneCount))
            .frame(width: 132)
            .disabled(session.loadedTune == nil)

            Spacer()

            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(.secondary)
            Slider(value: Binding {
                Double(session.soundVolume)
            } set: { value in
                session.soundVolume = Int(value.rounded())
            }, in: 0...100)
            .frame(width: 132)
            Text("\(session.soundVolume)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

private struct VSIDStatusChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.14), in: Capsule())
    }
}

private struct VSIDMetadataGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                content
            }
        }
    }
}

private struct VSIDMetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

private func firstNonEmpty(_ values: String?...) -> String {
    for value in values {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return "-"
}

private func formatElapsed(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval.rounded(.down)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private func hex(_ value: Int) -> String {
    String(format: "$%04X", value)
}

private func address(_ value: UInt32, fallback: Int?) -> String {
    if value > 0 {
        return String(format: "$%04X", value)
    }
    if let fallback, fallback > 0 {
        return hex(fallback)
    }
    return "-"
}

private func byteCount(_ value: Int) -> String {
    guard value > 0 else {
        return "-"
    }

    return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
}

private func isBlackPianoKey(_ semitone: Int) -> Bool {
    switch semitone % 12 {
    case 1, 3, 6, 8, 10:
        return true
    default:
        return false
    }
}

private func whiteKeyCount(beforeOrAt semitone: Int) -> Int {
    var count = 0
    for note in 0...semitone where !isBlackPianoKey(note) {
        count += 1
    }
    return count
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import Foundation

/// Interleaved signed 16-bit audio samples emitted by the VICE engine.
public struct MacVICEAudioSamples: Sendable {
    /// Raw interleaved PCM sample bytes.
    public let samples: Data
    /// Number of sample frames in `samples`.
    public let frameCount: Int
    /// Number of interleaved channels.
    public let channelCount: Int
    /// Sample rate in hertz.
    public let sampleRate: Int
    /// Monotonic audio packet sequence assigned by the VICE bridge.
    public let sequence: UInt64

    /// Creates an audio packet.
    public init(samples: Data,
                frameCount: Int,
                channelCount: Int,
                sampleRate: Int,
                sequence: UInt64) {
        self.samples = samples
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.sequence = sequence
    }
}

/// Source of VICE audio packets for consumers that want their own audio pipeline.
public protocol MacVICEAudioSource: AnyObject {
    /// Returns the latest packet only if its sequence differs from `sequence`.
    func copyLatestSamples(after sequence: UInt64) -> MacVICEAudioSamples?
    /// Returns the latest packet, if any.
    func copyLatestSamples() -> MacVICEAudioSamples?
}

/// Thread-safe in-memory audio source populated by `MacVICEEngineSession`.
public final class MacVICEAudioSampleSource: MacVICEAudioSource {
    private let lock = NSLock()
    private var latestSamples: MacVICEAudioSamples?

    /// Creates an empty audio source.
    public init() {}

    /// Publishes a new audio packet to consumers.
    public func publish(_ samples: MacVICEAudioSamples) {
        lock.withMacVICELock {
            latestSamples = samples
        }
    }

    /// Returns the latest packet only if its sequence differs from `sequence`.
    public func copyLatestSamples(after sequence: UInt64) -> MacVICEAudioSamples? {
        lock.withMacVICELock {
            guard let latestSamples,
                  latestSamples.sequence != sequence else {
                return nil
            }

            return latestSamples
        }
    }

    /// Returns the latest packet, if any.
    public func copyLatestSamples() -> MacVICEAudioSamples? {
        lock.withMacVICELock {
            latestSamples
        }
    }
}

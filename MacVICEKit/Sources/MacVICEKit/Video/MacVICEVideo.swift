import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One RGBA video frame emitted by the VICE engine.
public struct MacVICEVideoFrame: Sendable {
    /// Width in pixels.
    public let width: Int
    /// Height in pixels.
    public let height: Int
    /// Number of bytes between successive rows in `pixels`.
    public let bytesPerRow: Int
    /// Monotonic frame sequence assigned by the VICE bridge.
    public let sequence: UInt64
    /// RGBA pixel buffer.
    public let pixels: Data

    /// Creates a video frame from an RGBA pixel buffer.
    public init(width: Int,
                height: Int,
                bytesPerRow: Int,
                sequence: UInt64,
                pixels: Data) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.sequence = sequence
        self.pixels = pixels
    }
}

/// Placeholder frame size used before the VICE engine publishes real video.
public struct MacVICEBootFrame: Sendable, Equatable {
    /// Pixel dimensions to reserve for the display.
    public let pixelSize: CGSize

    /// Creates a boot frame size.
    public init(pixelSize: CGSize) {
        self.pixelSize = pixelSize
    }
}

/// Display metadata used to size and present a machine's video output.
public struct MacVICEDisplayProfile: Sendable, Equatable {
    /// Fallback frame used before the first real VICE frame.
    public let bootFrame: MacVICEBootFrame
    /// Default scale factor for a native-sized Mac window.
    public let nativeScale: CGFloat
    /// Pixel aspect ratio correction applied during presentation.
    public let pixelAspectRatio: CGFloat

    /// Creates a display profile.
    public init(bootFrame: MacVICEBootFrame,
                nativeScale: CGFloat = 2,
                pixelAspectRatio: CGFloat = 1) {
        self.bootFrame = bootFrame
        self.nativeScale = nativeScale
        self.pixelAspectRatio = pixelAspectRatio
    }

    /// Returns the display size after pixel aspect ratio correction.
    public func presentationSize(for pixelSize: CGSize) -> CGSize {
        CGSize(width: pixelSize.width * pixelAspectRatio,
               height: pixelSize.height)
    }

    /// Returns a native Mac window content size for a pixel size.
    public func nativeDisplaySize(for pixelSize: CGSize? = nil) -> CGSize {
        let sourceSize = pixelSize ?? bootFrame.pixelSize
        let presentedSize = presentationSize(for: sourceSize)
        return CGSize(width: presentedSize.width * nativeScale,
                      height: presentedSize.height * nativeScale)
    }
}

/// Source of VICE video frames for renderers and screenshot exporters.
public protocol MacVICEVideoSource: AnyObject {
    /// Returns the latest frame only if its sequence differs from `sequence`.
    func copyLatestFrame(after sequence: UInt64) -> MacVICEVideoFrame?
    /// Returns the latest frame, if any.
    func copyLatestFrame() -> MacVICEVideoFrame?
    /// Returns the presentation size after display-profile corrections.
    func presentationSize(for pixelSize: CGSize) -> CGSize
    /// Returns the native display size for the source.
    func nativeDisplaySize(for pixelSize: CGSize?) -> CGSize
}

/// Thread-safe in-memory video source populated by `MacVICEEngineSession`.
public final class MacVICEFrameSource: MacVICEVideoSource {
    /// Display profile used by consumers before frames arrive.
    public let displayProfile: MacVICEDisplayProfile
    /// Optional boot image shown before the first video frame.
    public let bootImageURL: URL?

    private let lock = NSLock()
    private var latestFrame: MacVICEVideoFrame?

    /// Creates an empty frame source.
    public init(displayProfile: MacVICEDisplayProfile,
                bootImageURL: URL? = nil) {
        self.displayProfile = displayProfile
        self.bootImageURL = bootImageURL
    }

    /// Publishes a new frame to consumers.
    public func publish(_ frame: MacVICEVideoFrame) {
        lock.withMacVICELock {
            latestFrame = frame
        }
    }

    /// Returns the latest frame only if its sequence differs from `sequence`.
    public func copyLatestFrame(after sequence: UInt64) -> MacVICEVideoFrame? {
        lock.withMacVICELock {
            guard let latestFrame,
                  latestFrame.sequence != sequence else {
                return nil
            }

            return latestFrame
        }
    }

    /// Returns the latest frame, if any.
    public func copyLatestFrame() -> MacVICEVideoFrame? {
        lock.withMacVICELock {
            latestFrame
        }
    }

    /// Returns the presentation size after display-profile corrections.
    public func presentationSize(for pixelSize: CGSize) -> CGSize {
        displayProfile.presentationSize(for: pixelSize)
    }

    /// Returns the native display size for the source.
    public func nativeDisplaySize(for pixelSize: CGSize? = nil) -> CGSize {
        displayProfile.nativeDisplaySize(for: pixelSize)
    }

    /// Encodes the latest frame as PNG data.
    public func latestScreenshotPNG() throws -> Data {
        guard let frame = copyLatestFrame() else {
            throw MacVICEError.engineFailure("No VICE video frame is available yet.")
        }

        return try Self.pngData(from: frame)
    }

    /// Encodes a frame as PNG data.
    public static func pngData(from frame: MacVICEVideoFrame) throws -> Data {
        guard frame.width > 0,
              frame.height > 0,
              frame.bytesPerRow >= frame.width * 4,
              frame.pixels.count >= frame.bytesPerRow * frame.height else {
            throw MacVICEError.engineFailure("The VICE video frame is invalid.")
        }

        guard let provider = CGDataProvider(data: frame.pixels as CFData),
              let image = CGImage(width: frame.width,
                                  height: frame.height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: frame.bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            throw MacVICEError.engineFailure("Unable to create a screenshot image from the VICE frame.")
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw MacVICEError.engineFailure("Unable to create a PNG encoder.")
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw MacVICEError.engineFailure("Unable to encode the VICE screenshot as PNG.")
        }

        return data as Data
    }
}

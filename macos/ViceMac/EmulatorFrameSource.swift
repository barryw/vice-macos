import CoreGraphics
import Foundation

struct EmulatorVideoFrame {
    let width: Int
    let height: Int
    let bytesPerRow: Int
    let sequence: UInt64
    let pixels: Data
}

final class EmulatorFrameSource {
    let resourceName: String
    let fileExtension: String
    let pixelSize: CGSize
    private let lock = NSLock()
    private var latestFrame: EmulatorVideoFrame?

    var aspectRatio: CGFloat {
        pixelSize.width / pixelSize.height
    }

    init(resourceName: String, fileExtension: String, pixelSize: CGSize) {
        self.resourceName = resourceName
        self.fileExtension = fileExtension
        self.pixelSize = pixelSize
    }

    func publish(_ frame: EmulatorVideoFrame) {
        lock.withLock {
            latestFrame = frame
        }
    }

    func copyLatestFrame(after sequence: UInt64) -> EmulatorVideoFrame? {
        lock.withLock {
            guard let latestFrame, latestFrame.sequence != sequence else {
                return nil
            }

            return latestFrame
        }
    }
}

extension EmulatorFrameSource {
    static func x64scReady() -> EmulatorFrameSource {
        EmulatorFrameSource(
            resourceName: "x64sc-ready",
            fileExtension: "png",
            pixelSize: CGSize(width: 384, height: 272)
        )
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}

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
    let displayProfile: MachineDisplayProfile
    private let lock = NSLock()
    private var latestFrame: EmulatorVideoFrame?

    var bootFrame: MachineBootFrame {
        displayProfile.bootFrame
    }

    var resourceName: String {
        bootFrame.resourceName
    }

    var fileExtension: String {
        bootFrame.fileExtension
    }

    var pixelSize: CGSize {
        bootFrame.pixelSize
    }

    var aspectRatio: CGFloat {
        let presentedSize = displayProfile.presentationSize(for: pixelSize)
        return presentedSize.width / presentedSize.height
    }

    init(displayProfile: MachineDisplayProfile) {
        self.displayProfile = displayProfile
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

    func copyLatestFrame() -> EmulatorVideoFrame? {
        lock.withLock {
            latestFrame
        }
    }

    func presentationSize(for pixelSize: CGSize) -> CGSize {
        displayProfile.presentationSize(for: pixelSize)
    }

    func nativeDisplaySize(for pixelSize: CGSize? = nil) -> CGSize {
        displayProfile.nativeDisplaySize(for: pixelSize)
    }
}

extension EmulatorFrameSource {
    static func displaySource(for machine: EmulatedMachine) -> EmulatorFrameSource {
        EmulatorFrameSource(displayProfile: machine.displayProfile)
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}

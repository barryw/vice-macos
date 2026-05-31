import Foundation

/// Errors thrown by MacVICEKit when configuration, runtime discovery, or the
/// VICE bridge cannot complete an operation.
public enum MacVICEError: Error, LocalizedError {
    /// A required VICE runtime directory, framework, dylib, or data directory was not found.
    case runtimeNotFound(String)
    /// The caller supplied configuration that MacVICEKit cannot convert into a valid VICE launch.
    case invalidConfiguration(String)
    /// The embedded VICE engine rejected an operation or reported a bridge failure.
    case engineFailure(String)
    /// The requested feature is not supported for the selected machine or runtime.
    case unsupported(String)

    /// A user-presentable error message suitable for alerts and logs.
    public var errorDescription: String? {
        switch self {
        case .runtimeNotFound(let message),
             .invalidConfiguration(let message),
             .engineFailure(let message),
             .unsupported(let message):
            return message
        }
    }
}

extension URL {
    var macVICEExistingDirectory: URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return self
    }
}

extension Array where Element == String {
    func withMacVICECStringArray<Result>(
        _ body: (Int32, UnsafePointer<UnsafePointer<CChar>?>?) -> Result
    ) -> Result? {
        guard count <= Int(Int32.max) else {
            return nil
        }

        var cStrings: [UnsafeMutablePointer<CChar>] = []
        cStrings.reserveCapacity(count)

        for string in self {
            guard let cString = strdup(string) else {
                for cString in cStrings {
                    free(cString)
                }
                return nil
            }
            cStrings.append(cString)
        }

        defer {
            for cString in cStrings {
                free(cString)
            }
        }

        var pointers = cStrings.map { Optional(UnsafePointer<CChar>($0)) }
        pointers.append(nil)

        return pointers.withUnsafeBufferPointer { buffer in
            body(Int32(count), buffer.baseAddress)
        }
    }
}

extension NSLock {
    func withMacVICELock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}

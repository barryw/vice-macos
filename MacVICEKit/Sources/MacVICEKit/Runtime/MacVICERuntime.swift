import Foundation

/// A runtime lookup strategy for the native VICE dylibs and data files.
public enum MacVICERuntimeLocation: Sendable, Equatable {
    /// Search known runtime locations, including `MACVICE_RUNTIME_DIR`, an embedded framework, and local checkout builds.
    case automatic
    /// Load runtime dylibs directly from a directory.
    case directory(URL)
    /// Load runtime dylibs and data files from a bundled `MacVICERuntime.framework`.
    case frameworkBundle(Bundle)
}

/// Resolved location of the native VICE runtime and its data directory.
public struct MacVICERuntime: Sendable, Equatable {
    /// Standard runtime framework bundle name used by MacVICEKit release artifacts.
    public static let frameworkName = "MacVICERuntime.framework"
    /// Bundle identifier used when resolving a loaded runtime framework automatically.
    public static let frameworkBundleIdentifier = "com.barrywalker.MacVICERuntime"
    /// Runtime manifest filename stored in packaged runtime artifacts.
    public static let manifestFileName = "MacVICERuntimeManifest.json"

    /// Directory containing `libvicemac*.dylib` runtime libraries.
    public let directoryURL: URL
    /// Directory containing VICE ROMs, keymaps, palettes, and other runtime data.
    public let dataDirectoryURL: URL

    /// Creates a resolved runtime location.
    public init(directoryURL: URL, dataDirectoryURL: URL) {
        self.directoryURL = directoryURL.macVICEStandardizedDirectoryURL
        self.dataDirectoryURL = dataDirectoryURL.macVICEStandardizedDirectoryURL
    }

    /// Returns the runtime dylib URL for a machine.
    public func dynamicLibraryURL(for machine: MacVICEMachine) -> URL {
        directoryURL.appendingPathComponent(machine.dynamicLibraryName)
    }

    /// Resolves and validates a runtime location for a machine.
    ///
    /// Validation ensures the machine-specific dylib exists and that the VICE
    /// data directory is present before engine startup begins.
    public static func resolve(location: MacVICERuntimeLocation = .automatic,
                               machine: MacVICEMachine) throws -> MacVICERuntime {
        let runtime: MacVICERuntime

        switch location {
        case .automatic:
            runtime = try resolveAutomatic()
        case .directory(let directoryURL):
            runtime = runtimeFromDirectory(directoryURL)
        case .frameworkBundle(let bundle):
            runtime = try runtimeFromFrameworkBundle(bundle)
        }

        try validate(runtime: runtime, machine: machine)
        return runtime
    }

    private static func resolveAutomatic() throws -> MacVICERuntime {
        if let environmentPath = ProcessInfo.processInfo.environment["MACVICE_RUNTIME_DIR"],
           !environmentPath.isEmpty {
            return runtimeFromDirectory(URL(fileURLWithPath: environmentPath, isDirectory: true))
        }

        if let runtimeBundle = Bundle(identifier: frameworkBundleIdentifier) {
            return try runtimeFromFrameworkBundle(runtimeBundle)
        }

        if let appRuntime = runtimeFromApplicationBundle(Bundle.main) {
            return appRuntime
        }

        if let checkoutRuntime = runtimeFromSourceCheckout() {
            return checkoutRuntime
        }

        throw MacVICEError.runtimeNotFound(
            "MacVICE runtime not found. Install the MacVICERuntime package artifact, set MACVICE_RUNTIME_DIR, or build the native Mac VICE runtime locally."
        )
    }

    private static func runtimeFromDirectory(_ directoryURL: URL) -> MacVICERuntime {
        let dataDirectoryCandidates = [
            directoryURL.appendingPathComponent("VICEData", isDirectory: true),
            directoryURL.appendingPathComponent("data", isDirectory: true)
        ]
        let dataDirectoryURL = dataDirectoryCandidates.first { $0.macVICEExistingDirectory != nil }
            ?? directoryURL.appendingPathComponent("VICEData", isDirectory: true)

        return MacVICERuntime(directoryURL: directoryURL,
                              dataDirectoryURL: dataDirectoryURL)
    }

    private static func runtimeFromFrameworkBundle(_ bundle: Bundle) throws -> MacVICERuntime {
        let runtimeCandidates = [
            bundle.privateFrameworksURL,
            bundle.resourceURL?.appendingPathComponent("Runtime", isDirectory: true)
        ].compactMap { $0 }

        guard let runtimeURL = runtimeCandidates.first(where: { $0.macVICEExistingDirectory != nil }) else {
            throw MacVICEError.runtimeNotFound("MacVICERuntime.framework does not contain a runtime dylib directory.")
        }

        let dataDirectoryURL = bundle.resourceURL?
            .appendingPathComponent("VICEData", isDirectory: true)
            ?? runtimeURL.appendingPathComponent("VICEData", isDirectory: true)

        return MacVICERuntime(directoryURL: runtimeURL,
                              dataDirectoryURL: dataDirectoryURL)
    }

    static func runtimeFromApplicationBundle(_ bundle: Bundle) -> MacVICERuntime? {
        if let embeddedFrameworkRuntime = runtimeFromEmbeddedFramework(in: bundle) {
            return embeddedFrameworkRuntime
        }

        guard let frameworksURL = bundle.privateFrameworksURL?.macVICEExistingDirectory,
              let resourcesURL = bundle.resourceURL else {
            return nil
        }

        let dataDirectoryURL = resourcesURL.appendingPathComponent("VICEData", isDirectory: true)
        guard dataDirectoryURL.macVICEExistingDirectory != nil else {
            return nil
        }

        return MacVICERuntime(directoryURL: frameworksURL,
                              dataDirectoryURL: dataDirectoryURL)
    }

    private static func runtimeFromEmbeddedFramework(in bundle: Bundle) -> MacVICERuntime? {
        let frameworkCandidates = [
            bundle.privateFrameworksURL?.appendingPathComponent(frameworkName, isDirectory: true),
            bundle.resourceURL?.appendingPathComponent(frameworkName, isDirectory: true)
        ].compactMap { $0?.macVICEExistingDirectory }

        for frameworkURL in frameworkCandidates {
            guard let runtimeBundle = Bundle(url: frameworkURL),
                  let runtime = try? runtimeFromFrameworkBundle(runtimeBundle) else {
                continue
            }
            return runtime
        }

        return nil
    }

    static func runtimeFromSourceCheckout(startingAt sourceURL: URL = URL(fileURLWithPath: #filePath)) -> MacVICERuntime? {
        for rootURL in sourceURL.macVICEAncestorDirectories {
            let buildProductsURL = rootURL
                .appendingPathComponent("macos", isDirectory: true)
                .appendingPathComponent("BuildProducts", isDirectory: true)
            let dataDirectoryURL = rootURL
                .appendingPathComponent("vice", isDirectory: true)
                .appendingPathComponent("data", isDirectory: true)

            guard buildProductsURL.macVICEExistingDirectory != nil,
                  dataDirectoryURL.macVICEExistingDirectory != nil else {
                continue
            }

            return MacVICERuntime(directoryURL: buildProductsURL,
                                  dataDirectoryURL: dataDirectoryURL)
        }

        return nil
    }

    private static func validate(runtime: MacVICERuntime,
                                 machine: MacVICEMachine) throws {
        let dynamicLibraryURL = runtime.dynamicLibraryURL(for: machine)
        guard FileManager.default.fileExists(atPath: dynamicLibraryURL.path) else {
            throw MacVICEError.runtimeNotFound("Missing VICE runtime library: \(dynamicLibraryURL.path)")
        }

        guard runtime.dataDirectoryURL.macVICEExistingDirectory != nil else {
            throw MacVICEError.runtimeNotFound("Missing VICE data directory: \(runtime.dataDirectoryURL.path)")
        }
    }
}

private extension URL {
    var macVICEStandardizedDirectoryURL: URL {
        URL(fileURLWithPath: absoluteURL.path, isDirectory: true).standardizedFileURL
    }

    var macVICEAncestorDirectories: [URL] {
        var directories: [URL] = []
        var currentURL = URL(fileURLWithPath: absoluteURL.path, isDirectory: hasDirectoryPath)
            .standardizedFileURL

        if !currentURL.hasDirectoryPath {
            currentURL.deleteLastPathComponent()
        }

        while true {
            directories.append(currentURL)
            let parentURL = currentURL.deletingLastPathComponent()
            guard parentURL.path != currentURL.path else {
                return directories
            }
            currentURL = parentURL
        }
    }
}

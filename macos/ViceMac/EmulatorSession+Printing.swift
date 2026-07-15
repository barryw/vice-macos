import AppKit
import Foundation
import ImageIO
import MacVICEKit
import UniformTypeIdentifiers

extension EmulatorSession {
    nonisolated static func printSpoolDirectoryURL(for machine: EmulatedMachine) -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL
            .appendingPathComponent("mac VICE", isDirectory: true)
            .appendingPathComponent("Print Spool", isDirectory: true)
            .appendingPathComponent(machine.id.rawValue, isDirectory: true)
    }

    var printSpoolDirectoryURL: URL {
        Self.printSpoolDirectoryURL(for: machine)
    }

    var printSpoolBaseURL: URL {
        printSpoolDirectoryURL.appendingPathComponent(PrinterSpoolPage.filenamePrefix)
    }

    var printSpoolBasePath: String {
        printSpoolBaseURL.path
    }

    var printQueueStatusTitle: String {
        switch printSpoolPages.count {
        case 0:
            return "No pages"
        case 1:
            return "1 page"
        default:
            return "\(printSpoolPages.count) pages"
        }
    }

    func refreshPrintQueue() {
        preparePrintSpoolDirectory()
        let pages = Self.loadPrintSpoolPages(from: printSpoolDirectoryURL)
        if pages != printSpoolPages {
            printSpoolPages = pages
        }
    }

    func clearPrintQueue() {
        for page in printSpoolPages {
            try? FileManager.default.removeItem(at: page.url)
        }
        refreshPrintQueue()
        statusText = "Print queue cleared"
    }

    @discardableResult
    func exportPrintQueuePDF(to url: URL) -> Bool {
        refreshPrintQueue()
        guard !printSpoolPages.isEmpty else {
            statusText = "No printed pages"
            return false
        }

        do {
            try Self.writePDF(pages: printSpoolPages, to: url)
            rememberMedia(url)
            statusText = "Printout saved"
            return true
        } catch {
            statusText = "Unable to save printout"
            return false
        }
    }

    func printQueuedPages() {
        refreshPrintQueue()
        guard !printSpoolPages.isEmpty else {
            statusText = "No printed pages"
            return
        }

        let view = PrinterSpoolPrintView(pageURLs: printSpoolPages.map(\.url))
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let operation = NSPrintOperation(view: view, printInfo: printInfo)
        operation.jobTitle = "\(machine.shortName) Printout"
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    func startPrintQueueMonitoring() {
        printQueueTimer?.invalidate()
        printQueueTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPrintQueue()
            }
        }
    }

    func preparePrintSpoolDirectory() {
        try? FileManager.default.createDirectory(at: printSpoolDirectoryURL,
                                                 withIntermediateDirectories: true)
    }

    private static func loadPrintSpoolPages(from directoryURL: URL) -> [PrinterSpoolPage] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directoryURL,
                                                                      includingPropertiesForKeys: [
                                                                        .contentModificationDateKey,
                                                                        .fileSizeKey,
                                                                        .isRegularFileKey
                                                                      ],
                                                                      options: [.skipsHiddenFiles]) else {
            return []
        }

        return urls
            .filter { url in
                url.pathExtension.lowercased() == "bmp"
                    && url.deletingPathExtension().lastPathComponent.hasPrefix(PrinterSpoolPage.filenamePrefix)
            }
            .compactMap { url -> PrinterSpoolPage? in
                guard let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey
                ]),
                      values.isRegularFile == true else {
                    return nil
                }

                return PrinterSpoolPage(url: url,
                                        byteCount: values.fileSize ?? 0,
                                        modifiedAt: values.contentModificationDate ?? .distantPast)
            }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.url.lastPathComponent < rhs.url.lastPathComponent
                }
                return lhs.modifiedAt < rhs.modifiedAt
            }
    }

    static func writePNG(frame: MacVICEVideoFrame, to url: URL) throws {
        guard frame.width > 0,
              frame.height > 0,
              frame.bytesPerRow >= frame.width * 4,
              frame.pixels.count >= frame.bytesPerRow * frame.height else {
            throw CocoaError(.fileWriteUnknown)
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
                                  intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                               UTType.png.identifier as CFString,
                                                               1,
                                                               nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func writePDF(pages: [PrinterSpoolPage], to url: URL) throws {
        let renderedPages = try pages.map { page -> (image: CGImage, box: CGRect) in
            let source = try imageSource(for: page.url)
            let image = try cgImage(from: source)
            return (image, pdfPageBox(for: source, image: image))
        }

        guard let firstPage = renderedPages.first else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        var mediaBox = firstPage.box
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for page in renderedPages {
            var pageBox = page.box
            let pageInfo = withUnsafeBytes(of: &pageBox) { bytes in
                [kCGPDFContextMediaBox as String: Data(bytes) as CFData] as CFDictionary
            }
            context.beginPDFPage(pageInfo)
            context.interpolationQuality = .none
            context.draw(page.image, in: pageBox)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func imageSource(for url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return source
    }

    private static func cgImage(from source: CGImageSource) throws -> CGImage {
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return image
    }

    private static func pdfPageBox(for source: CGImageSource, image: CGImage) -> CGRect {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpiX = properties?[kCGImagePropertyDPIWidth] as? CGFloat ?? 72
        let dpiY = properties?[kCGImagePropertyDPIHeight] as? CGFloat ?? 72
        let width = CGFloat(image.width) * 72 / max(dpiX, 1)
        let height = CGFloat(image.height) * 72 / max(dpiY, 1)

        return CGRect(x: 0, y: 0, width: max(width, 1), height: max(height, 1))
    }
}

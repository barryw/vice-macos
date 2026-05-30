import AppKit

final class PrinterSpoolPrintView: NSView {
    private let images: [NSImage]
    private let paperSize: NSSize

    init(pageURLs: [URL]) {
        images = pageURLs.compactMap(NSImage.init(contentsOf:))
        let printInfo = NSPrintInfo.shared
        paperSize = printInfo.paperSize
        super.init(frame: NSRect(x: 0,
                                 y: 0,
                                 width: max(printInfo.paperSize.width, 1),
                                 height: max(printInfo.paperSize.height * CGFloat(max(images.count, 1)), 1)))
    }

    required init?(coder: NSCoder) {
        images = []
        paperSize = NSPrintInfo.shared.paperSize
        super.init(coder: coder)
    }

    override var isFlipped: Bool {
        true
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: max(images.count, 1))
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0,
               y: CGFloat(max(page - 1, 0)) * paperSize.height,
               width: paperSize.width,
               height: paperSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()

        for (index, image) in images.enumerated() {
            let pageRect = rectForPage(index + 1)
            guard dirtyRect.intersects(pageRect) else {
                continue
            }

            let destination = image.size.scaledToFit(in: pageRect.insetBy(dx: 36, dy: 36))
            image.draw(in: destination,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1)
        }
    }
}

private extension NSSize {
    func scaledToFit(in rect: NSRect) -> NSRect {
        guard width > 0,
              height > 0,
              rect.width > 0,
              rect.height > 0 else {
            return rect
        }

        let scale = min(rect.width / width, rect.height / height)
        let scaledSize = NSSize(width: width * scale, height: height * scale)

        return NSRect(x: rect.midX - scaledSize.width / 2,
                      y: rect.midY - scaledSize.height / 2,
                      width: scaledSize.width,
                      height: scaledSize.height)
    }
}

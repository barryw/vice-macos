import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: window-id.swift <owner-name> [title-contains]\n", stderr)
    exit(2)
}

let ownerName = CommandLine.arguments[1]
let titleNeedle = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : ""
let includesAllWindows = ProcessInfo.processInfo.environment["VICE_MAC_WINDOW_LIST_ALL"] == "1"
let options: CGWindowListOption = includesAllWindows
    ? [.optionAll, .excludeDesktopElements]
    : [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
    guard let owner = window[kCGWindowOwnerName as String] as? String,
          owner == ownerName else {
        continue
    }

    let layer = window[kCGWindowLayer as String] as? Int ?? Int.max
    let alpha = window[kCGWindowAlpha as String] as? Double ?? 0
    guard layer == 0, alpha > 0 else {
        continue
    }

    let title = window[kCGWindowName as String] as? String ?? ""
    guard titleNeedle.isEmpty ||
          title.localizedCaseInsensitiveContains(titleNeedle) else {
        continue
    }

    if let number = window[kCGWindowNumber as String] {
        print(number)
        exit(0)
    }
}

exit(1)

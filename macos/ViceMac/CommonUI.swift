import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VMCStatusBadge: View {
    let text: String
    var systemImage: String?
    var color: Color = .secondary

    init(_ text: String,
         systemImage: String? = nil,
         color: Color = .secondary) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
            }

            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .lineLimit(1)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.70), in: Capsule())
    }
}

struct VMCInfoRow<Content: View>: View {
    let title: String
    let labelWidth: CGFloat
    let content: Content

    init(_ title: String,
         labelWidth: CGFloat = 48,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.labelWidth = labelWidth
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

struct VMCSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let sendsSearchStringImmediately: Bool

    init(_ placeholder: String,
         text: Binding<String>,
         sendsSearchStringImmediately: Bool = true) {
        self.placeholder = placeholder
        _text = text
        self.sendsSearchStringImmediately = sendsSearchStringImmediately
    }

    init(text: Binding<String>,
         placeholder: String,
         sendsSearchStringImmediately: Bool = true) {
        self.init(placeholder,
                  text: text,
                  sendsSearchStringImmediately: sendsSearchStringImmediately)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = sendsSearchStringImmediately
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        context.coordinator.text = $text

        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        if searchField.placeholderString != placeholder {
            searchField.placeholderString = placeholder
        }

        if searchField.sendsSearchStringImmediately != sendsSearchStringImmediately {
            searchField.sendsSearchStringImmediately = sendsSearchStringImmediately
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }

            text.wrappedValue = searchField.stringValue
        }
    }
}

struct VMCIconButton: View {
    let systemImage: String
    let help: String
    var role: ButtonRole?
    var width: CGFloat = 28
    var height: CGFloat = 26
    let action: () -> Void

    init(_ systemImage: String,
         help: String,
         role: ButtonRole? = nil,
         width: CGFloat = 28,
         height: CGFloat = 26,
         action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.help = help
        self.role = role
        self.width = width
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .frame(width: width, height: height)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct VMCEmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String?
    let actions: Actions

    init(_ title: String,
         systemImage: String,
         description: String? = nil,
         @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        } actions: {
            actions
        }
    }
}

struct VMCPopoverHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

/// Icon + title + subtitle header shared by the hand-rolled modal sheets
/// (new disk image, GEOS package assistant, rename file, …). Matches the
/// `HStack(spacing: 12) { Image…; VStack(title, subtitle) }` markup those
/// sheets previously hand-rolled identically.
struct VMCSheetHeader: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The status-chip-that-opens-a-popover pattern shared by the drive and
/// cartridge indicators. Owns the capsule padding/shape, plain button style,
/// `isPresented` background tint, help text, and popover wiring; callers
/// supply their own LED/glyph + text content and popover body.
struct VMCIndicatorChip<Label: View, Popover: View>: View {
    @Binding var isPresented: Bool
    let help: String
    @ViewBuilder var label: () -> Label
    @ViewBuilder var popover: () -> Popover

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            label()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(isPresented ? Color.secondary.opacity(0.18) : Color.clear, in: Capsule())
        .help(help)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popover()
        }
    }
}

/// Shared NSOpenPanel / NSSavePanel configuration so every file picker in the
/// app activates and centers itself the same way. Pass `nil` for a property
/// to leave the panel's own default untouched, and an empty
/// `allowedContentTypes` to allow every file type.
@MainActor
enum AppFilePanel {
    /// Configures and runs an `NSOpenPanel` modally.
    /// - Returns: the chosen URLs, or `nil` if the panel was cancelled.
    @discardableResult
    static func chooseFiles(title: String,
                            message: String? = nil,
                            prompt: String? = nil,
                            canChooseFiles: Bool = true,
                            canChooseDirectories: Bool = false,
                            allowsMultipleSelection: Bool = false,
                            allowedContentTypes: [UTType] = [],
                            canCreateDirectories: Bool? = nil,
                            directoryURL: URL? = nil) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        if let message {
            panel.message = message
        }
        if let prompt {
            panel.prompt = prompt
        }
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = allowsMultipleSelection
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        if let canCreateDirectories {
            panel.canCreateDirectories = canCreateDirectories
        }
        if let directoryURL {
            panel.directoryURL = directoryURL
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls
    }

    /// Configures and runs an `NSSavePanel` modally.
    /// - Returns: the destination URL, or `nil` if the panel was cancelled.
    @discardableResult
    static func chooseSaveURL(title: String,
                              message: String? = nil,
                              prompt: String? = nil,
                              nameFieldStringValue: String? = nil,
                              allowedContentTypes: [UTType] = [],
                              canCreateDirectories: Bool? = nil,
                              directoryURL: URL? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        if let message {
            panel.message = message
        }
        if let prompt {
            panel.prompt = prompt
        }
        if let nameFieldStringValue {
            panel.nameFieldStringValue = nameFieldStringValue
        }
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        if let canCreateDirectories {
            panel.canCreateDirectories = canCreateDirectories
        }
        if let directoryURL {
            panel.directoryURL = directoryURL
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}

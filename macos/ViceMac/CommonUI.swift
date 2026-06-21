import AppKit
import SwiftUI

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
    }
}

struct VMCEmptyState: View {
    let title: String
    let systemImage: String
    let description: String?

    init(_ title: String,
         systemImage: String,
         description: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
    }

    @ViewBuilder
    var body: some View {
        if let description {
            ContentUnavailableView(title,
                                   systemImage: systemImage,
                                   description: Text(description))
        } else {
            ContentUnavailableView(title,
                                   systemImage: systemImage)
        }
    }
}

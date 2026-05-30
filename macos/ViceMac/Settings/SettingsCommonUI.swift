import AppKit
import SwiftUI

struct SettingsCustomPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
    }
}

struct SettingsTableContainer<Content: View, Footer: View>: View {
    let minHeight: CGFloat
    private let content: Content
    private let footer: Footer

    init(minHeight: CGFloat,
         @ViewBuilder content: () -> Content,
         @ViewBuilder footer: () -> Footer) {
        self.minHeight = minHeight
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(minHeight: minHeight)

            Divider()

            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.55))
        }
    }
}

struct SettingsSheetLayout<Content: View, Actions: View>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat?
    let minHeight: CGFloat?
    private let content: Content
    private let actions: Actions

    init(title: String,
         width: CGFloat,
         height: CGFloat? = nil,
         minHeight: CGFloat? = nil,
         @ViewBuilder content: () -> Content,
         @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.width = width
        self.height = height
        self.minHeight = minHeight
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            content

            HStack {
                Spacer()
                actions
            }
        }
        .padding(22)
        .frame(width: width)
        .frame(height: height)
        .frame(minHeight: minHeight)
    }
}

struct SettingsValueText: View {
    let text: String
    let lineLimit: Int?
    let truncationMode: Text.TruncationMode
    let color: Color

    init(_ text: String,
         lineLimit: Int? = 1,
         truncationMode: Text.TruncationMode = .tail,
         color: Color = .secondary) {
        self.text = text
        self.lineLimit = lineLimit
        self.truncationMode = truncationMode
        self.color = color
    }

    var body: some View {
        Text(text)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .truncationMode(truncationMode)
    }
}

struct SettingsSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        if searchField.placeholderString != placeholder {
            searchField.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private var text: Binding<String>

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

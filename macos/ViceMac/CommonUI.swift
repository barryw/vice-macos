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

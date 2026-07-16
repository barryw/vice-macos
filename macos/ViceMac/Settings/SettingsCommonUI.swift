import SwiftUI

enum SettingsPaneID: String, CaseIterable, Identifiable {
    case machine
    case media
    case metadata
    case sound
    case controls
    case keyboard
    case drives
    case printing
    case network
    case display
    case ai

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .machine:
            return "Machine"
        case .media:
            return "Media"
        case .metadata:
            return "Metadata"
        case .sound:
            return "Sound"
        case .controls:
            return "Controls"
        case .keyboard:
            return "Keyboard"
        case .drives:
            return "Storage"
        case .printing:
            return "Printing"
        case .network:
            return "Network"
        case .display:
            return "Display"
        case .ai:
            return "AI"
        }
    }

    var subtitle: String {
        switch self {
        case .machine:
            return "Model, ROMs, memory"
        case .media:
            return "Library, files, tape"
        case .metadata:
            return "Database imports, APIs"
        case .sound:
            return "SID and audio output"
        case .controls:
            return "Joysticks and mice"
        case .keyboard:
            return "Keymaps and bindings"
        case .drives:
            return "Drives and storage"
        case .printing:
            return "Printers and queue"
        case .network:
            return "Modem and Q-Link"
        case .display:
            return "Video and filters"
        case .ai:
            return "Assistant settings"
        }
    }

    var systemImage: String {
        switch self {
        case .machine:
            return "cpu"
        case .media:
            return "externaldrive.badge.plus"
        case .metadata:
            return "tag"
        case .sound:
            return "speaker.wave.2"
        case .controls:
            return "gamecontroller"
        case .keyboard:
            return "keyboard"
        case .drives:
            return "externaldrive"
        case .printing:
            return "printer"
        case .network:
            return "network"
        case .display:
            return "display"
        case .ai:
            return "sparkles"
        }
    }

    /// Power-user / niche panes. Grouped under an "Advanced" heading in the
    /// sidebar so everyday machine settings carry the visual weight and these
    /// don't sit at the same depth as Machine or Sound.
    var isAdvanced: Bool {
        switch self {
        case .metadata, .network, .ai:
            return true
        default:
            return false
        }
    }
}

enum SettingsPaneCatalog {
    static func availablePanes(showsControlSettings: Bool,
                               showsNetworkSettings: Bool,
                               aiAssistantEnabled: Bool) -> [SettingsPaneID] {
        SettingsPaneID.allCases.filter { pane in
            switch pane {
            case .controls:
                return showsControlSettings
            case .network:
                return showsNetworkSettings
            case .ai:
                return aiAssistantEnabled
            default:
                return true
            }
        }
    }

    static func normalizedSelection(for rawSelection: String,
                                    showsControlSettings: Bool,
                                    showsNetworkSettings: Bool,
                                    aiAssistantEnabled: Bool) -> SettingsPaneID {
        let selectedPane = SettingsPaneID(rawValue: rawSelection) ?? .machine

        if selectedPane == .controls,
           !showsControlSettings {
            return .keyboard
        }

        if selectedPane == .network,
           !showsNetworkSettings {
            return .media
        }

        if selectedPane == .ai,
           !aiAssistantEnabled {
            return .machine
        }

        let panes = availablePanes(showsControlSettings: showsControlSettings,
                                   showsNetworkSettings: showsNetworkSettings,
                                   aiAssistantEnabled: aiAssistantEnabled)
        return panes.contains(selectedPane) ? selectedPane : panes.first ?? .machine
    }
}

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

struct SettingsPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SettingsCustomPane {
            Form {
                content
            }
            .formStyle(.grouped)
        }
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

struct SettingsSheetLayout<Header: View, Content: View, ActionsLeading: View, Actions: View>: View {
    let width: CGFloat
    let height: CGFloat?
    let minHeight: CGFloat?
    private let header: Header
    private let content: Content
    private let actionsLeading: ActionsLeading
    private let actions: Actions

    /// Plain-title header, as used by every pre-existing caller.
    init(title: String,
         width: CGFloat,
         height: CGFloat? = nil,
         minHeight: CGFloat? = nil,
         @ViewBuilder content: () -> Content,
         @ViewBuilder actionsLeading: () -> ActionsLeading = { EmptyView() },
         @ViewBuilder actions: () -> Actions) where Header == Text {
        self.width = width
        self.height = height
        self.minHeight = minHeight
        self.header = Text(title).font(.title3.weight(.semibold))
        self.content = content()
        self.actionsLeading = actionsLeading()
        self.actions = actions()
    }

    /// Custom header (e.g. `VMCSheetHeader`) for sheets whose header is more
    /// than a bare title.
    init(width: CGFloat,
         height: CGFloat? = nil,
         minHeight: CGFloat? = nil,
         @ViewBuilder header: () -> Header,
         @ViewBuilder content: () -> Content,
         @ViewBuilder actionsLeading: () -> ActionsLeading = { EmptyView() },
         @ViewBuilder actions: () -> Actions) {
        self.width = width
        self.height = height
        self.minHeight = minHeight
        self.header = header()
        self.content = content()
        self.actionsLeading = actionsLeading()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            content

            HStack {
                actionsLeading
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

struct SettingsFilePathRow: View {
    struct Action: Identifiable {
        let id = UUID()
        let title: String
        var isEnabled = true
        var role: ButtonRole? = nil
        let action: () -> Void
    }

    let title: String
    let value: String
    var valueLineLimit: Int? = 1
    var chooseTitle: String = "Choose…"
    // ponytail: no separate icon-only path here; the one row that needs an icon (Q-Link disk) opts in via chooseSystemImage.
    var chooseSystemImage: String? = nil
    let onChoose: () -> Void
    var trailing: [Action] = []

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                SettingsValueText(value, lineLimit: valueLineLimit, truncationMode: .middle)

                Spacer(minLength: 8)

                chooseButton

                ForEach(trailing) { action in
                    Button(action.title, role: action.role, action: action.action)
                        .disabled(!action.isEnabled)
                }
            }
        }
    }

    @ViewBuilder
    private var chooseButton: some View {
        if let chooseSystemImage {
            Button(action: onChoose) {
                Label(chooseTitle, systemImage: chooseSystemImage)
            }
        } else {
            Button(chooseTitle, action: onChoose)
        }
    }
}

struct SettingsSliderControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueTitle: String
    var leadingTitle: String?
    var leadingWidth: CGFloat = 112
    var isEnabled = true
    var valueWidth: CGFloat = 48
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 10) {
            if let leadingTitle {
                Text(leadingTitle)
                    .frame(width: leadingWidth, alignment: .leading)
            }

            Slider(value: $value,
                   in: range,
                   onEditingChanged: onEditingChanged)
                .disabled(!isEnabled)
                .accessibilityLabel(leadingTitle ?? valueTitle)

            Text(valueTitle)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: valueWidth, alignment: .trailing)
        }
    }
}

struct SettingsPercentSlider: View {
    @Binding var value: Int
    var isEnabled = true
    var valueWidth: CGFloat = 44
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        SettingsSliderControl(value: doubleBinding,
                              range: 0...100,
                              valueTitle: "\(value)%",
                              isEnabled: isEnabled,
                              valueWidth: valueWidth,
                              onEditingChanged: onEditingChanged)
    }

    private var doubleBinding: Binding<Double> {
        Binding {
            Double(value)
        } set: { newValue in
            value = min(max(Int(newValue.rounded()), 0), 100)
        }
    }
}

struct SettingsPortField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 72

    var body: some View {
        HStack(spacing: 6) {
            TextField("Port",
                      value: boundedValue,
                      format: .number.grouping(.never))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: width)

            Stepper("Port", value: boundedValue, in: range)
                .labelsHidden()
        }
    }

    private var boundedValue: Binding<Int> {
        Binding {
            value
        } set: { newValue in
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }
    }
}

typealias SettingsSearchField = VMCSearchField

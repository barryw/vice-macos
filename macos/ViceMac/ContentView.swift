import AppKit
import MacVICEKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @EnvironmentObject private var qLinkReloaded: QLinkReloadedService
    @State private var showingFilterPanel = false
    @State private var isFullScreen = false
    @State private var topChromeActive = false
    @State private var bottomChromeActive = false
    @State private var isAssistantVisible = false
    @State private var contentLayoutTopInset: CGFloat = 0
    @AppStorage("vice.ai.assistantSidebarWidth", store: UserDefaults(suiteName: "com.barrywalker.vicemac"))
    private var assistantSidebarWidth = MainWindowLayoutMetrics.defaultAssistantSidebarWidth

    var body: some View {
        HStack(spacing: 0) {
            emulatorPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsAssistantSidebar {
                AssistantSidebarRegion(width: $assistantSidebarWidth,
                                       sidebarWidth: clampedAssistantSidebarWidth,
                                       topInset: contentLayoutTopInset)
                    .frame(width: assistantSidebarReservedWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showsAssistantSidebar)
        .background(Color.black)
        .overlay {
            WindowChromeObserver(isFullScreen: $isFullScreen,
                                 topChromeActive: $topChromeActive,
                                 bottomChromeActive: $bottomChromeActive,
                                 contentLayoutTopInset: $contentLayoutTopInset,
                                 machine: emulator.machine,
                                 frameSource: emulator.frameSource,
                                 rightSidebarWidth: assistantSidebarReservedWidth)
                .allowsHitTesting(false)
        }
        .background {
            AssistantSidebarWindowResizer(isVisible: showsAssistantSidebar,
                                          sidebarWidth: assistantSidebarReservedWidth,
                                          minimumDisplayWidth: emulator.frameSource.nativeDisplaySize().width)
        }
        .toolbar {
            ToolbarItemGroup {
                MachineToolbarControls()

                InputToolbarControls()

                if emulator.machine.capabilities.supportsVideoStandardSelection {
                    Picker("Video", selection: $emulator.videoStandard) {
                        ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 118)
                    .help("Video standard")
                }

                if emulator.machine.supportsDisplayOutputSelection {
                    DisplayOutputToolbarPicker()
                }

                if emulator.machine.usesVIC20MemoryExpansion {
                    VIC20MemoryToolbarMenu()
                }

                SoundToolbarControls()
            }

            ToolbarItemGroup {
                DisplaySettingsToolbarControls(showingFilterPanel: $showingFilterPanel)
            }

            if qLinkReloaded.supports(machine: emulator.machine) {
                ToolbarItem {
                    QLinkReloadedToolbarButton()
                }
            }

            if aiSettings.isConfigured {
                ToolbarItem {
                    AIAssistantToolbarButton(isVisible: $isAssistantVisible)
                }
            }
        }
        .onAppear {
            emulator.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            emulator.handleApplicationActivationChanged(isActive: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            emulator.handleApplicationActivationChanged(isActive: true)
        }
        .onOpenURL { url in
            emulator.openMedia(url: url)
        }
        .onChange(of: aiSettings.isConfigured) { _, isConfigured in
            if !isConfigured {
                isAssistantVisible = false
            }
        }
        .alert(item: $emulator.startupError) { error in
            Alert(title: Text(error.title),
                  message: Text(error.message),
                  dismissButton: .default(Text("OK")))
        }
        .alert(item: $qLinkReloaded.alert) { alert in
            switch alert.kind {
            case .message:
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      dismissButton: .default(Text("OK")))
            case .incompatibleSettings:
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      primaryButton: .cancel(Text("Cancel")),
                      secondaryButton: .default(Text("Set them for me")) {
                          qLinkReloaded.setQLinkRequiredSettingsAndConnect(emulator: emulator)
                      })
            }
        }
    }

    private var showsAssistantSidebar: Bool {
        isAssistantVisible && aiSettings.isConfigured
    }

    private var assistantSidebarReservedWidth: CGFloat {
        showsAssistantSidebar
            ? MainWindowLayoutMetrics.assistantSidebarTotalWidth(for: clampedAssistantSidebarWidth)
            : 0
    }

    private var clampedAssistantSidebarWidth: CGFloat {
        MainWindowLayoutMetrics.clampedAssistantSidebarWidth(CGFloat(assistantSidebarWidth))
    }

    private var emulatorPane: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                EmulatorDisplaySurface()

                if !isFullScreen {
                    Divider()
                    EmulatorStatusBar()
                }
            }

            if isFullScreen {
                EmulatorStatusBar()
                    .background(.regularMaterial)
                    .overlay(alignment: .top) {
                        Divider()
                    }
                    .opacity(bottomChromeActive ? 1 : 0)
                    .offset(y: bottomChromeActive ? 0 : 38)
                    .animation(.easeOut(duration: 0.16), value: bottomChromeActive)
                    .allowsHitTesting(bottomChromeActive)
            }
        }
    }
}

private struct QLinkReloadedToolbarButton: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var qLinkReloaded: QLinkReloadedService

    var body: some View {
        Button {
            qLinkReloaded.connect(emulator: emulator)
        } label: {
            Label(buttonTitle, systemImage: "network")
        }
        .disabled(qLinkReloaded.isConnecting)
        .help(helpText)
    }

    private var buttonTitle: String {
        qLinkReloaded.isConnecting ? "Connecting to Q-Link Reloaded" : "Connect to Q-Link Reloaded"
    }

    private var helpText: String {
        if qLinkReloaded.isConnecting {
            return "Connecting to Q-Link Reloaded"
        }

        if let configuredDiskTitle = qLinkReloaded.configuredDiskTitle,
           let configuredDiskVersionTitle = qLinkReloaded.configuredDiskVersionTitle {
            return "Connect to Q-Link Reloaded with \(configuredDiskTitle) (\(configuredDiskVersionTitle))"
        }

        if let configuredDiskTitle = qLinkReloaded.configuredDiskTitle {
            return "Connect to Q-Link Reloaded with \(configuredDiskTitle)"
        }

        return "Choose a Q-Link disk, configure the modem, and connect to Q-Link Reloaded"
    }
}

private struct AIAssistantToolbarButton: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            Label("Assistant", systemImage: "sparkles")
        }
        .foregroundStyle(isVisible ? Color.accentColor : Color.primary)
        .help(isVisible ? "Hide assistant" : "Open assistant for \(emulator.machineDisplayName)")
    }
}

private struct AIAssistantChatSidebar: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @EnvironmentObject private var aiDocumentLibrary: AIDocumentLibraryStore
    var topContentInset: CGFloat = 0
    @State private var draft = ""
    @State private var messages: [AIAssistantChatMessage] = []
    @State private var statusText = "Ready."
    @State private var isRunning = false
    @State private var composerFocusRequest = UUID()
    @State private var conversationService: AIAssistantConversationService?

    var body: some View {
        VStack(spacing: 0) {
            transcriptView

            Divider()

            composerView
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            requestComposerFocus()
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if topContentInset > 0 {
                        Color.clear
                            .frame(height: topContentInset)
                    }

                    ForEach(messages) { message in
                        AIAssistantChatMessageRow(message: message)
                    }

                    if isRunning {
                        AIAssistantWorkingMessageRow()
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(with: proxy)
            }
            .onChange(of: isRunning) { _, _ in
                scrollToBottom(with: proxy)
            }
        }
    }

    private var composerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Button {
                    clearConversation()
                } label: {
                    Label("Clear Conversation", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(messages.isEmpty && draft.isEmpty && !isRunning)
                .help("Clear conversation")
            }

            HStack(alignment: .bottom, spacing: 8) {
                AIAssistantChatInputView(text: $draft,
                                         isEnabled: !isRunning,
                                         focusRequest: composerFocusRequest,
                                         onSubmit: submitAssistantPrompt)
                    .frame(height: 68)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.separator.opacity(0.55))
                    }

                Button {
                    submitAssistantPrompt()
                } label: {
                    Label("Send", systemImage: "paperplane")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSubmitDraft || isRunning)
                .keyboardShortcut(.defaultAction)
                .help("Send")
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var canSubmitDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitAssistantPrompt() {
        guard !isRunning else {
            return
        }

        Task {
            await submitAssistantPrompt()
        }
    }

    private func submitAssistantPrompt() async {
        let submittedPrompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedPrompt.isEmpty else {
            return
        }

        messages.append(AIAssistantChatMessage(role: .user,
                                               text: submittedPrompt,
                                               toolUseCount: 0))
        draft = ""
        isRunning = true
        statusText = "Working..."

        do {
            let result = try await activeConversationService().run(prompt: submittedPrompt,
                                                                   settings: aiSettings)
            messages.append(AIAssistantChatMessage(role: .assistant,
                                                   text: result.text,
                                                   toolUseCount: result.toolUseCount))
            if result.toolUseCount == 0 {
                statusText = "Done."
            } else {
                let noun = result.toolUseCount == 1 ? "tool" : "tools"
                statusText = "Done. Used \(result.toolUseCount) \(noun)."
            }
        } catch {
            messages.append(AIAssistantChatMessage(role: .assistant,
                                                   text: error.localizedDescription,
                                                   toolUseCount: 0))
            statusText = error.localizedDescription
        }

        isRunning = false
        requestComposerFocus()
    }

    private func activeConversationService() -> AIAssistantConversationService {
        if let conversationService {
            return conversationService
        }

        let service = AIAssistantConversationService(emulator: emulator,
                                                     documentLibrary: aiDocumentLibrary)
        conversationService = service
        return service
    }

    private func clearConversation() {
        guard !isRunning else {
            return
        }

        messages = []
        draft = ""
        statusText = "Ready."
        conversationService?.reset()
        requestComposerFocus()
    }

    private func requestComposerFocus() {
        composerFocusRequest = UUID()
    }

    private func scrollToBottom(with proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private static let bottomAnchorID = "assistant-chat-bottom"
}

private struct AIAssistantChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant

        var transcriptName: String {
            switch self {
            case .user:
                return "User"
            case .assistant:
                return "Assistant"
            }
        }
    }

    let id = UUID()
    let role: Role
    let text: String
    let toolUseCount: Int
}

private struct AIAssistantChatMessageRow: View {
    let message: AIAssistantChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 36)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .textSelection(.enabled)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if message.role == .assistant,
                   message.toolUseCount > 0 {
                    Text(toolUseTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: 292, alignment: .leading)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(bubbleBorder)
            }

            if message.role == .assistant {
                Spacer(minLength: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var bubbleBackground: Color {
        switch message.role {
        case .user:
            return .accentColor.opacity(0.16)
        case .assistant:
            return Color(nsColor: .controlBackgroundColor).opacity(0.72)
        }
    }

    private var bubbleBorder: Color {
        switch message.role {
        case .user:
            return .accentColor.opacity(0.22)
        case .assistant:
            return Color(nsColor: .separatorColor).opacity(0.45)
        }
    }

    private var toolUseTitle: String {
        let noun = message.toolUseCount == 1 ? "VM tool" : "VM tools"
        return "Used \(message.toolUseCount) \(noun)"
    }
}

private struct AIAssistantWorkingMessageRow: View {
    var body: some View {
        HStack(spacing: 10) {
            AIAssistantKITTScannerView()

            Text("Working...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator.opacity(0.45))
        }
    }
}

private struct AIAssistantKITTScannerView: View {
    private let segmentCount = 11

    var body: some View {
        TimelineView(.animation) { timeline in
            let activeIndex = activeSegmentIndex(at: timeline.date)

            HStack(spacing: 3) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    let strength = segmentStrength(index: index, activeIndex: activeIndex)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(scannerColor.opacity(0.18 + (0.82 * strength)))
                        .frame(width: 8, height: 13)
                        .shadow(color: scannerColor.opacity(0.22 * strength),
                                radius: 4,
                                x: 0,
                                y: 0)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.18))
            }
        }
        .frame(width: 126, height: 25)
        .accessibilityLabel("Assistant working")
        .help("Assistant working")
    }

    private var scannerColor: Color {
        Color(red: 1.0, green: 0.08, blue: 0.05)
    }

    private func activeSegmentIndex(at date: Date) -> Int {
        let maxIndex = segmentCount - 1
        let cycleLength = maxIndex * 2
        let step = Int((date.timeIntervalSinceReferenceDate * 14).truncatingRemainder(dividingBy: Double(cycleLength)))
        return step <= maxIndex ? step : cycleLength - step
    }

    private func segmentStrength(index: Int, activeIndex: Int) -> Double {
        let distance = abs(index - activeIndex)
        switch distance {
        case 0:
            return 1.0
        case 1:
            return 0.62
        case 2:
            return 0.32
        default:
            return 0.0
        }
    }
}

private struct AIAssistantChatInputView: NSViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool
    let focusRequest: UUID
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = AIAssistantComposerTextView()
        textView.delegate = context.coordinator
        textView.submitAction = { [weak coordinator = context.coordinator] in
            coordinator?.submit()
        }
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 7, height: 7)
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width,
                                                       height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.update(text: $text, onSubmit: onSubmit)
        guard let textView = scrollView.documentView as? AIAssistantComposerTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = isEnabled
        textView.alphaValue = isEnabled ? 1 : 0.66
        textView.submitAction = { [weak coordinator = context.coordinator] in
            coordinator?.submit()
        }
        context.coordinator.applyFocusIfNeeded(focusRequest, to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        private var onSubmit: () -> Void
        private var appliedFocusRequest: UUID?

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func update(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }

        func submit() {
            onSubmit()
        }

        func applyFocusIfNeeded(_ focusRequest: UUID, to textView: NSTextView) {
            guard appliedFocusRequest != focusRequest else {
                return
            }

            appliedFocusRequest = focusRequest
            DispatchQueue.main.async { [weak textView] in
                guard let textView,
                      let window = textView.window else {
                    return
                }

                window.makeFirstResponder(textView)
            }
        }
    }
}

private final class AIAssistantComposerTextView: NSTextView {
    var submitAction: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn,
           !event.modifierFlags.contains(.shift) {
            submitAction?()
            return
        }

        super.keyDown(with: event)
    }
}

private enum MainWindowLayoutMetrics {
    static let statusBarHeight: CGFloat = 36
    static let statusBarDividerHeight: CGFloat = 1
    static let defaultAssistantSidebarWidth = 380.0
    static let minimumAssistantSidebarWidth: CGFloat = 300
    static let maximumAssistantSidebarWidth: CGFloat = 680
    static let assistantSidebarDividerWidth: CGFloat = 1
    static let assistantSidebarResizeHandleWidth: CGFloat = 7

    static var contentHeightOutsideDisplay: CGFloat {
        statusBarHeight + statusBarDividerHeight
    }

    static func clampedAssistantSidebarWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumAssistantSidebarWidth), maximumAssistantSidebarWidth)
    }

    static func assistantSidebarTotalWidth(for width: CGFloat) -> CGFloat {
        clampedAssistantSidebarWidth(width) + assistantSidebarDividerWidth + assistantSidebarResizeHandleWidth
    }
}

private struct AssistantSidebarRegion: View {
    @Binding var width: Double
    let sidebarWidth: CGFloat
    let topInset: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            AssistantSidebarSplitChrome(width: $width,
                                        topInset: clampedTopInset)

            AIAssistantChatSidebar(topContentInset: clampedTopInset)
                .frame(width: sidebarWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private var clampedTopInset: CGFloat {
        max(0, topInset)
    }
}

private struct AssistantSidebarSplitChrome: View {
    @Binding var width: Double
    let topInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(0, topInset))

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: MainWindowLayoutMetrics.assistantSidebarDividerWidth)
                    .frame(maxHeight: .infinity)
                    .frame(width: MainWindowLayoutMetrics.assistantSidebarDividerWidth)

                AssistantSidebarResizeHandle(width: $width)
                    .frame(width: MainWindowLayoutMetrics.assistantSidebarResizeHandleWidth)
                    .frame(maxHeight: .infinity)
                    .frame(width: MainWindowLayoutMetrics.assistantSidebarResizeHandleWidth)
            }
                .frame(maxHeight: .infinity)
        }
        .frame(width: MainWindowLayoutMetrics.assistantSidebarDividerWidth +
            MainWindowLayoutMetrics.assistantSidebarResizeHandleWidth)
    }
}

private struct AssistantSidebarResizeHandle: View {
    @Binding var width: Double
    @State private var dragStartWidth: Double?
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Color.accentColor.opacity(0.22) : Color.clear)
            .overlay(alignment: .center) {
                Capsule()
                    .fill(Color.secondary.opacity(isHovering ? 0.55 : 0.26))
                    .frame(width: 2, height: 42)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startingWidth = dragStartWidth ?? width
                        dragStartWidth = startingWidth
                        let proposedWidth = startingWidth - Double(value.translation.width)
                        width = Double(MainWindowLayoutMetrics.clampedAssistantSidebarWidth(CGFloat(proposedWidth)))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                        width = Double(MainWindowLayoutMetrics.clampedAssistantSidebarWidth(CGFloat(width)))
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .help("Resize assistant")
    }
}

private struct AssistantSidebarWindowResizer: NSViewRepresentable {
    let isVisible: Bool
    let sidebarWidth: CGFloat
    let minimumDisplayWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.update(window: view.window,
                                   isVisible: isVisible,
                                   sidebarWidth: sidebarWidth,
                                   minimumDisplayWidth: minimumDisplayWidth)
    }

    @MainActor
    final class Coordinator {
        private var wasVisible = false

        func update(window: NSWindow?,
                    isVisible: Bool,
                    sidebarWidth: CGFloat,
                    minimumDisplayWidth: CGFloat) {
            guard let window else {
                if !isVisible {
                    wasVisible = false
                }
                return
            }

            let shouldResize = isVisible && !wasVisible && !window.styleMask.contains(.fullScreen)
            wasVisible = isVisible
            guard shouldResize else {
                return
            }

            let contentWidth = window.contentLayoutRect.width
            let projectedDisplayWidth = contentWidth - sidebarWidth
            let deficit = minimumDisplayWidth - projectedDisplayWidth
            guard deficit > 1 else {
                return
            }

            var frame = window.frame
            let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            let maximumWidth = screenFrame?.width ?? CGFloat.greatestFiniteMagnitude
            frame.size.width = min(frame.width + deficit, maximumWidth)

            if let screenFrame,
               frame.maxX > screenFrame.maxX {
                frame.origin.x = max(screenFrame.minX, screenFrame.maxX - frame.width)
            }

            window.setFrame(frame, display: true, animate: false)
        }
    }
}

private struct EmulatorStatusBar: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 14) {
            Label(emulator.machine.shortName, systemImage: "cpu")
                .lineLimit(1)
            if let modelTitle = emulator.machineModelStatusTitle {
                StatusPill(text: modelTitle)
                    .help(emulator.machineDisplayName)
            }
            if emulator.machine.capabilities.supportsVideoStandardSelection {
                StatusPill(text: emulator.videoStandard.rawValue)
            }
            if emulator.machine.capabilities.supportsSIDModelSelection {
                StatusPill(text: emulator.sidModel.title)
            }
            if emulator.machine.supportsDisplayOutputSelection {
                StatusPill(text: emulator.displayOutput.statusTitle)
            }
            StatusPill(text: emulator.isPaused ? "Paused" : "READY")
            StatusPill(text: emulator.filterSettings.preset.toolbarTitle)
            if emulator.isRAMExpansionConfigured {
                RAMExpansionStatusChip()
            }
            ForEach(emulator.availableControlPorts) { port in
                ControlPortStatusIndicator(port: port)
            }

            Spacer()

            if emulator.machine.capabilities.supportsCartridges {
                CartridgeIndicator()
            }

            ForEach(emulator.visibleDriveActivities) { drive in
                DriveIndicator(drive: drive)
            }
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .frame(height: MainWindowLayoutMetrics.statusBarHeight)
    }
}

private struct EmulatorDisplaySurface: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let displaySize = size(for: proxy.size)

            ZStack {
                Color.black

                MacVICEDisplayView(videoSource: emulator.frameSource,
                                    inputHandlers: inputHandlers,
                                    configuration: displayConfiguration)
                    .frame(width: displaySize.width,
                           height: displaySize.height)
                    .overlay {
                        if emulator.isPaused {
                            PausedDisplayOverlay()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.14), value: emulator.isPaused)

                if isDropTargeted {
                    MediaDropOverlay()
                        .transition(.opacity)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleMediaDrop(providers)
            }
        }
        .frame(minWidth: nativeSize.width, minHeight: nativeSize.height)
        .background(Color.black)
    }

    private var nativeSize: CGSize {
        emulator.frameSource.nativeDisplaySize()
    }

    private var displayConfiguration: MacVICEDisplayConfiguration {
        MacVICEDisplayConfiguration(
            preservesAspectRatio: emulator.displayMode.preservesAspectRatio,
            filtering: .nearest,
            filterSettings: MacVICEVideoFilterSettings(emulator.filterSettings),
            forwardsInput: true,
            capturesMouse: emulator.isMacMouseInputActive,
            bootImageURL: emulator.frameSource.bootImageURL
        )
    }

    private var inputHandlers: MacVICEDisplayInputHandlers {
        MacVICEDisplayInputHandlers(onKeyEvent: emulator.handleKeyEvent,
                                    onFlagsChanged: emulator.handleFlagsChanged,
                                    onMouseMoved: emulator.handleMouseMoved,
                                    onMouseButton: emulator.handleMouseButton,
                                    onMouseCaptureChanged: emulator.handleMouseCaptureChanged,
                                    onPaste: { emulator.pasteFromPasteboard() },
                                    onFocusLost: emulator.releaseAllKeys)
    }

    private func size(for containerSize: CGSize) -> CGSize {
        switch emulator.displayMode {
        case .native:
            return nativeSize
        case .fit:
            return CGSize(width: max(containerSize.width, 1),
                          height: max(containerSize.height, 1))
        case .stretch:
            return CGSize(width: max(containerSize.width, 1),
                          height: max(containerSize.height, 1))
        }
    }

    private func handleMediaDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileURLTypeIdentifier = UTType.fileURL.identifier
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(fileURLTypeIdentifier)
        }

        guard !fileProviders.isEmpty else {
            return false
        }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: fileURLTypeIdentifier, options: nil) { item, _ in
                guard let url = Self.fileURL(from: item) else {
                    return
                }

                DispatchQueue.main.async {
                    emulator.openMedia(url: url)
                }
            }
        }

        return true
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

private struct PausedDisplayOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.24))

            Image(systemName: "pause.fill")
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 112, height: 112)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.36), radius: 24, y: 12)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Paused")
    }
}

private struct MediaDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.32))

            VStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text("Open Media")
                    .font(.headline)
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Drop media to open")
    }
}

private struct InputToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        ViewThatFits(in: .horizontal) {
            controls(portWidth: 58, showsPortTitle: true, showsSwapButton: true)
            controls(portWidth: 42, showsPortTitle: false, showsSwapButton: true)
            controls(portWidth: 42, showsPortTitle: false, showsSwapButton: false)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func controls(portWidth: CGFloat,
                          showsPortTitle: Bool,
                          showsSwapButton: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach(emulator.availableControlPorts) { port in
                ControlPortToolbarMenu(port: port,
                                       width: portWidth,
                                       showsPortTitle: showsPortTitle)
            }

            if emulator.hasMultipleControlPorts && showsSwapButton {
                Button {
                    emulator.swapControlPorts()
                } label: {
                    ToolbarIconLabel(title: "Swap Control Ports",
                                     systemImage: "arrow.left.arrow.right")
                }
                .frame(width: 44)
                .buttonStyle(.plain)
                .help("Swap control ports")
            }
        }
    }
}

private struct ControlPortStatusIndicator: View {
    @EnvironmentObject private var emulator: EmulatorSession

    let port: ControlPort

    var body: some View {
        let device = emulator.controlPortDevice(for: port)
        let connectionState = emulator.controlPortConnectionState(for: port)

        ViewThatFits(in: .horizontal) {
            indicatorContent(device: device,
                             connectionState: connectionState,
                             showsPortTitle: true,
                             showsInputDots: true)
                .frame(width: 96)
            indicatorContent(device: device,
                             connectionState: connectionState,
                             showsPortTitle: true,
                             showsInputDots: false)
                .frame(width: 50)
            indicatorContent(device: device,
                             connectionState: connectionState,
                             showsPortTitle: false,
                             showsInputDots: false)
                .frame(width: 28)
        }
        .frame(height: 22)
        .background(.quaternary.opacity(0.7), in: Capsule())
        .help(helpText(device: device, connectionState: connectionState))
        .layoutPriority(-1)
    }

    private func indicatorContent(device: ControlDeviceConfiguration?,
                                  connectionState: ControlDeviceConnectionState,
                                  showsPortTitle: Bool,
                                  showsInputDots: Bool) -> some View {
        HStack(spacing: 6) {
            if showsPortTitle {
                Text("P\(port.rawValue)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }

            Image(systemName: device?.systemImage ?? "slash.circle")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint(for: connectionState, hasDevice: device != nil))

            if showsInputDots {
                ControlPortInputDots(activeActions: emulator.controlPortActiveActions(for: port),
                                     isEnabled: device != nil && connectionState.isConnected)
            }
        }
        .padding(.horizontal, showsInputDots ? 8 : 6)
    }

    private func iconTint(for connectionState: ControlDeviceConnectionState,
                          hasDevice: Bool) -> Color {
        guard hasDevice else {
            return .secondary
        }

        return connectionState.isConnected ? .primary : .orange
    }

    private func helpText(device: ControlDeviceConfiguration?,
                          connectionState: ControlDeviceConnectionState) -> String {
        guard let device else {
            return "\(port.title): None"
        }

        let deviceTitle = device.kind == .joystick
            ? "\(device.name) - \(emulator.hardwareTitle(for: device))"
            : device.name

        guard connectionState.isConnected else {
            return "\(port.title): \(deviceTitle) - \(connectionState.title)"
        }

        let activeActions = emulator.controlPortActiveActions(for: port)
        guard !activeActions.isEmpty else {
            return "\(port.title): \(deviceTitle) - idle"
        }

        let actionText = JoystickAction.allCases
            .filter { activeActions.contains($0) }
            .map(\.title)
            .joined(separator: ", ")
        return "\(port.title): \(deviceTitle) - \(actionText)"
    }
}

private struct ControlPortInputDots: View {
    let activeActions: Set<JoystickAction>
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(JoystickAction.allCases) { action in
                Image(systemName: systemImage(for: action))
                    .font(.system(size: action == .fire ? 6 : 7, weight: .semibold))
                    .frame(width: 8, height: 8)
                    .foregroundStyle(tint(for: action))
            }
        }
        .frame(width: 48, height: 8)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func systemImage(for action: JoystickAction) -> String {
        switch action {
        case .up:
            return "arrowtriangle.up.fill"
        case .down:
            return "arrowtriangle.down.fill"
        case .left:
            return "arrowtriangle.left.fill"
        case .right:
            return "arrowtriangle.right.fill"
        case .fire:
            return "circle.fill"
        }
    }

    private func tint(for action: JoystickAction) -> Color {
        guard isEnabled else {
            return .secondary.opacity(0.28)
        }

        return activeActions.contains(action) ? .accentColor : .secondary.opacity(0.28)
    }
}

private struct ControlPortToolbarMenu: View {
    @EnvironmentObject private var emulator: EmulatorSession

    let port: ControlPort
    var width: CGFloat = 58
    var showsPortTitle = true

    var body: some View {
        Menu {
            Button {
                emulator.setControlPortDeviceID(nil, for: port)
            } label: {
                if emulator.controlPortDeviceID(for: port) == nil {
                    Label("None", systemImage: "checkmark")
                } else {
                    Label("None", systemImage: "slash.circle")
                }
            }

            if !emulator.controlDevices.isEmpty {
                Divider()
            }

            ForEach(emulator.controlDevices) { device in
                Button {
                    emulator.setControlPortDeviceID(device.id, for: port)
                } label: {
                    let connectionState = emulator.connectionState(for: device)
                    let deviceTitle = menuTitle(for: device)
                    let title = connectionState.isConnected
                        ? deviceTitle
                        : "\(deviceTitle) - \(connectionState.title)"

                    if emulator.controlPortDeviceID(for: port) == device.id {
                        Label(title, systemImage: connectionState.isConnected ? "checkmark" : connectionState.systemImage)
                    } else {
                        Label(title, systemImage: connectionState.isConnected ? device.systemImage : connectionState.systemImage)
                    }
                }
            }

            if emulator.controlDevices.isEmpty {
                Text("No control devices")
            }
        } label: {
            HStack(spacing: 5) {
                if showsPortTitle {
                    Text("P\(port.rawValue)")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }

                Image(systemName: toolbarSystemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(toolbarTint)
            }
            .frame(width: width)
        }
        .help(helpText)
    }

    private var toolbarSystemImage: String {
        guard let device = emulator.controlPortDevice(for: port) else {
            return "slash.circle"
        }

        let connectionState = emulator.connectionState(for: device)
        return connectionState.isConnected ? device.systemImage : connectionState.systemImage
    }

    private var toolbarTint: Color {
        guard let device = emulator.controlPortDevice(for: port) else {
            return .secondary
        }

        return emulator.connectionState(for: device).isConnected ? .primary : .orange
    }

    private var helpText: String {
        guard let device = emulator.controlPortDevice(for: port) else {
            return "\(port.title): None"
        }

        let connectionState = emulator.connectionState(for: device)
        if connectionState.isConnected {
            return "\(port.title): \(menuTitle(for: device))"
        }

        return "\(port.title): \(menuTitle(for: device)) - \(connectionState.title)"
    }

    private func menuTitle(for device: ControlDeviceConfiguration) -> String {
        guard device.kind == .joystick else {
            return device.name
        }

        return "\(device.name) (\(emulator.hardwareTitle(for: device)))"
    }
}

private struct MachineToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 8) {
            Button {
                emulator.togglePause()
            } label: {
                ToolbarIconLabel(title: emulator.isPaused ? "Resume" : "Pause",
                                 systemImage: emulator.isPaused ? "play.fill" : "pause.fill")
            }
            .frame(width: 44)
            .help(emulator.isPaused ? "Resume \(emulator.machine.shortName)" : "Pause \(emulator.machine.shortName)")

            Menu {
                Button {
                    emulator.reset(kind: .soft)
                } label: {
                    Label(MachineResetKind.soft.title, systemImage: "restart")
                }

                Button {
                    emulator.reset(kind: .hard)
                } label: {
                    Label(MachineResetKind.hard.title, systemImage: "power")
                }
            } label: {
                ToolbarIconLabel(title: "Reset", systemImage: "restart")
            }
            .frame(width: 58)
            .help("Reset \(emulator.machine.shortName)")

            Menu {
                ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                    Button {
                        emulator.emulationSpeed = speed
                    } label: {
                        if emulator.emulationSpeed == speed {
                            Label(speed.title, systemImage: "checkmark")
                        } else {
                            Text(speed.title)
                        }
                    }
                }
            } label: {
                ToolbarIconLabel(title: emulator.emulationSpeed.toolbarTitle,
                                 systemImage: emulator.emulationSpeed.isWarpEnabled
                                    ? "forward.end.fill"
                                    : "gauge.with.dots.needle.67percent")
            }
            .frame(width: 58)
            .help("Emulation speed")
        }
        .fixedSize()
    }
}

private struct DisplayToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Menu {
            ForEach(EmulatorSession.DisplayMode.allCases) { mode in
                Button {
                    emulator.displayMode = mode
                } label: {
                    if emulator.displayMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }

            Divider()

            Button {
                WindowActions.toggleFullScreen()
            } label: {
                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        } label: {
            ToolbarIconLabel(title: emulator.displayMode.toolbarTitle,
                             systemImage: emulator.displayMode.systemImage)
        }
        .frame(width: 58)
        .help("Display size")
    }
}

private struct DisplaySettingsToolbarControls: View {
    @Binding var showingFilterPanel: Bool

    var body: some View {
        HStack(spacing: 8) {
            DisplayToolbarControls()

            VideoFilterPresetPicker()
                .fixedSize()
                .help("Display profile")

            Button {
                showingFilterPanel.toggle()
            } label: {
                ToolbarIconLabel(title: "Tune Display", systemImage: "slider.horizontal.3")
            }
            .frame(width: 58)
            .help("Custom display settings")
            .popover(isPresented: $showingFilterPanel, arrowEdge: .bottom) {
                VideoFilterToolbarPanel()
            }
        }
        .fixedSize()
    }
}

private struct DisplayOutputToolbarPicker: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Picker("Display Output", selection: $emulator.displayOutput) {
            ForEach(emulator.machine.displayOutputs) { output in
                Label(output.toolbarTitle, systemImage: output.systemImage)
                    .tag(output)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 96)
        .help("C128 display output")
    }
}

private struct VIC20MemoryToolbarMenu: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Menu {
            ForEach(emulator.machine.ramExpansions) { expansion in
                Button {
                    emulator.ramExpansion = expansion
                } label: {
                    if emulator.ramExpansion == expansion {
                        Label(expansion.displayTitle(for: emulator.machine), systemImage: "checkmark")
                    } else {
                        Text(expansion.displayTitle(for: emulator.machine))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "memorychip")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(toolbarTitle)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 78)
        }
        .help("VIC-20 memory")
    }

    private var toolbarTitle: String {
        emulator.ramExpansion == .none ? "5K" : emulator.ramExpansion.chipTitle
    }
}

enum WindowActions {
    @MainActor
    static func toggleFullScreen() {
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        window?.toggleFullScreen(nil)
    }
}

enum WindowFrameRestoration {
    @MainActor
    static func saveOpenWindowFrames() {
        let machine = EmulatedMachine.current
        var didSave = false

        for window in NSApp.windows
            where isMainWindow(window, for: machine) {
            didSave = saveFrame(for: window, machine: machine) || didSave
            if !window.frameAutosaveName.isEmpty {
                window.saveFrame(usingName: window.frameAutosaveName)
            }
        }

        if !didSave,
           let fallbackWindow = NSApp.mainWindow ?? NSApp.keyWindow {
            didSave = saveFrame(for: fallbackWindow, machine: machine)
        }

        if didSave {
            UserDefaults.standard.synchronize()
        }
    }

    @MainActor
    @discardableResult
    static func saveFrame(for window: NSWindow, machine: EmulatedMachine, flush: Bool = false) -> Bool {
        guard window.isVisible,
              !window.isMiniaturized,
              !window.styleMask.contains(.fullScreen),
              window.frame.width.isFinite,
              window.frame.height.isFinite,
              window.frame.width > 0,
              window.frame.height > 0 else {
            return false
        }

        EmulatorDefaults.saveMainWindowFrame(window.frame, for: machine)
        if flush {
            UserDefaults.standard.synchronize()
        }
        return true
    }

    @MainActor
    static func restoreFrame(for window: NSWindow, machine: EmulatedMachine) {
        guard !window.styleMask.contains(.fullScreen),
              let frame = EmulatorDefaults.loadMainWindowFrame(for: machine) else {
            return
        }

        window.setFrame(clampedToVisibleScreens(frame), display: true)
    }

    private static func clampedToVisibleScreens(_ frame: CGRect) -> CGRect {
        guard let screenFrame = destinationScreen(for: frame)?.visibleFrame else {
            return frame
        }

        var clamped = frame
        clamped.size.width = min(clamped.width, screenFrame.width)
        clamped.size.height = min(clamped.height, screenFrame.height)

        if clamped.maxX > screenFrame.maxX {
            clamped.origin.x = screenFrame.maxX - clamped.width
        }
        if clamped.minX < screenFrame.minX {
            clamped.origin.x = screenFrame.minX
        }
        if clamped.maxY > screenFrame.maxY {
            clamped.origin.y = screenFrame.maxY - clamped.height
        }
        if clamped.minY < screenFrame.minY {
            clamped.origin.y = screenFrame.minY
        }

        return clamped
    }

    private static func destinationScreen(for frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return nil
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let containingScreen = screens.first(where: { $0.visibleFrame.contains(center) }) {
            return containingScreen
        }

        return screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
        } ?? NSScreen.main ?? screens[0]
    }

    @MainActor
    private static func isMainWindow(_ window: NSWindow, for machine: EmulatedMachine) -> Bool {
        let autosaveName = NSWindow.FrameAutosaveName(machine.mainWindowFrameAutosaveName)
        if window.frameAutosaveName == autosaveName {
            return true
        }

        return window.identifier?.rawValue == machine.mainWindowIdentifier
    }
}

private struct WindowChromeObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    @Binding var topChromeActive: Bool
    @Binding var bottomChromeActive: Bool
    @Binding var contentLayoutTopInset: CGFloat
    let machine: EmulatedMachine
    let frameSource: MacVICEFrameSource
    let rightSidebarWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(observer: self)
    }

    func makeNSView(context: Context) -> WindowChromeObserverView {
        let view = WindowChromeObserverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: WindowChromeObserverView, context: Context) {
        context.coordinator.update(observer: self)
        context.coordinator.attach(to: view.window)
    }

    @MainActor
    final class Coordinator: NSObject {
        private var observer: WindowChromeObserver
        private weak var window: NSWindow?
        private var mouseMonitor: Any?
        private var notificationObservers: [NSObjectProtocol] = []
        private var previousToolbarVisibility: Bool?
        private var previousAcceptsMouseMovedEvents: Bool?
        private var configuredFrameAutosaveName: String?
        private var deferredRestoreTask: Task<Void, Never>?
        private var deferredSaveTask: Task<Void, Never>?
        private var isRestoringPersistedFrame = false
        private weak var previousWindowDelegate: (any NSWindowDelegate)?
        private var aspectResizeState: AspectResizeState?
        private let resizeDelegate = WindowResizeAspectRatioDelegate()
        private let revealThreshold: CGFloat = 74

        init(observer: WindowChromeObserver) {
            self.observer = observer
            super.init()
            resizeDelegate.coordinator = self
        }

        deinit {
            MainActor.assumeIsolated {
                detach()
            }
        }

        func update(observer: WindowChromeObserver) {
            self.observer = observer
            configureFrameRestoration()
            updateWindowChrome()
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                configureFrameRestoration()
                updateFullScreenState()
                return
            }

            detach()
            self.window = window

            guard let window else {
                setFullScreen(false)
                return
            }

            installResizeDelegate(on: window)
            configureFrameRestoration()

            let center = NotificationCenter.default
            notificationObservers = [
                center.addObserver(forName: NSWindow.didEnterFullScreenNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.setFullScreen(true)
                    }
                },
                center.addObserver(forName: NSWindow.didExitFullScreenNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.setFullScreen(false)
                    }
                },
                center.addObserver(forName: NSWindow.didMoveNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrameSoon()
                    }
                },
                center.addObserver(forName: NSWindow.didResizeNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.updateContentLayoutTopInset()
                        self?.saveCurrentFrameSoon()
                    }
                },
                center.addObserver(forName: NSWindow.didEndLiveResizeNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.updateContentLayoutTopInset()
                        self?.aspectResizeState = nil
                        self?.saveCurrentFrame(flush: true)
                    }
                },
                center.addObserver(forName: NSWindow.willCloseNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrame(flush: true)
                    }
                }
            ]

            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleMouseMoved(event)
                }
                return event
            }

            updateFullScreenState()
            updateContentLayoutTopInset()
        }

        private func detach() {
            saveCurrentFrame(flush: true)
            deferredSaveTask?.cancel()
            deferredSaveTask = nil

            if let mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
                self.mouseMonitor = nil
            }

            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()

            if let window,
               let previousToolbarVisibility {
                window.toolbar?.isVisible = previousToolbarVisibility
            }
            if let window,
               let previousAcceptsMouseMovedEvents {
                window.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
            }
            if let window,
               window.delegate === resizeDelegate {
                window.delegate = previousWindowDelegate
            }
            previousToolbarVisibility = nil
            previousAcceptsMouseMovedEvents = nil
            previousWindowDelegate = nil
            aspectResizeState = nil
            resizeDelegate.fallback = nil
            configuredFrameAutosaveName = nil
            deferredRestoreTask?.cancel()
            deferredRestoreTask = nil
            isRestoringPersistedFrame = false
            window = nil
        }

        private func installResizeDelegate(on window: NSWindow) {
            guard window.delegate !== resizeDelegate else {
                return
            }

            previousWindowDelegate = window.delegate
            resizeDelegate.fallback = previousWindowDelegate
            window.delegate = resizeDelegate
        }

        fileprivate func frameSize(for window: NSWindow,
                                   proposedFrameSize: NSSize) -> NSSize {
            guard !window.styleMask.contains(.fullScreen),
                  isAspectResizeModifierActive else {
                aspectResizeState = nil
                return proposedFrameSize
            }

            guard let state = aspectResizeState ?? makeAspectResizeState(for: window,
                                                                         proposedFrameSize: proposedFrameSize) else {
                return proposedFrameSize
            }

            aspectResizeState = state
            return Self.aspectLockedFrameSize(for: window,
                                              proposedFrameSize: proposedFrameSize,
                                              state: state)
        }

        private var isAspectResizeModifierActive: Bool {
            !NSEvent.modifierFlags.intersection([.shift, .command]).isEmpty
        }

        private func currentDisplayAspectRatio() -> CGFloat {
            let displaySize: CGSize
            if let frame = observer.frameSource.copyLatestFrame() {
                displaySize = observer.frameSource.presentationSize(
                    for: CGSize(width: frame.width, height: frame.height)
                )
            } else {
                displaySize = observer.frameSource.nativeDisplaySize()
            }

            guard displaySize.width > 0,
                  displaySize.height > 0 else {
                return 0
            }

            return displaySize.width / displaySize.height
        }

        private func makeAspectResizeState(for window: NSWindow,
                                           proposedFrameSize: NSSize) -> AspectResizeState? {
            let displayAspectRatio = currentDisplayAspectRatio()
            guard displayAspectRatio > 0 else {
                return nil
            }

            let proposedFrame = CGRect(origin: window.frame.origin,
                                       size: proposedFrameSize)
            let proposedContentSize = window.contentRect(forFrameRect: proposedFrame).size
            let currentContentSize = window.contentRect(forFrameRect: window.frame).size
            let widthDelta = abs(proposedContentSize.width - currentContentSize.width)
            let heightDelta = abs(proposedContentSize.height - currentContentSize.height)
            let drivingDimension: AspectResizeState.DrivingDimension = widthDelta >= heightDelta
                ? .width
                : .height

            return AspectResizeState(displayAspectRatio: displayAspectRatio,
                                     drivingDimension: drivingDimension,
                                     widthOutsideDisplay: observer.rightSidebarWidth)
        }

        private static func aspectLockedFrameSize(for window: NSWindow,
                                                  proposedFrameSize: NSSize,
                                                  state: AspectResizeState) -> NSSize {
            let proposedFrame = CGRect(origin: window.frame.origin,
                                       size: proposedFrameSize)
            let proposedContentSize = window.contentRect(forFrameRect: proposedFrame).size
            let heightOutsideDisplay = MainWindowLayoutMetrics.contentHeightOutsideDisplay
            let widthOutsideDisplay = state.widthOutsideDisplay
            let contentSize: CGSize

            switch state.drivingDimension {
            case .width:
                let displayWidth = max(proposedContentSize.width - widthOutsideDisplay, 1)
                contentSize = CGSize(width: displayWidth + widthOutsideDisplay,
                                     height: displayWidth / state.displayAspectRatio + heightOutsideDisplay)
            case .height:
                let proposedDisplayHeight = max(proposedContentSize.height - heightOutsideDisplay, 1)
                contentSize = CGSize(width: proposedDisplayHeight * state.displayAspectRatio + widthOutsideDisplay,
                                     height: proposedDisplayHeight + heightOutsideDisplay)
            }

            let constrainedFrame = window.frameRect(forContentRect: CGRect(origin: .zero,
                                                                           size: contentSize))
            return constrainedFrame.size
        }

        private func configureFrameRestoration() {
            let frameAutosaveName = observer.machine.mainWindowFrameAutosaveName
            guard let window,
                  configuredFrameAutosaveName != frameAutosaveName else {
                return
            }

            let autosaveName = NSWindow.FrameAutosaveName(frameAutosaveName)
            configuredFrameAutosaveName = frameAutosaveName
            window.identifier = NSUserInterfaceItemIdentifier(observer.machine.mainWindowIdentifier)
            window.isRestorable = true
            window.setFrameAutosaveName(autosaveName)

            if EmulatorDefaults.loadMainWindowFrame(for: observer.machine) == nil {
                window.setFrameUsingName(autosaveName, force: true)
                saveCurrentFrameSoon()
                return
            }

            isRestoringPersistedFrame = true
            restorePersistedFrame()
            restorePersistedFrameAfterSwiftUILayout()
        }

        private func restorePersistedFrame() {
            guard let window else {
                return
            }

            WindowFrameRestoration.restoreFrame(for: window, machine: observer.machine)
        }

        private func restorePersistedFrameAfterSwiftUILayout() {
            deferredRestoreTask?.cancel()
            deferredRestoreTask = Task { @MainActor [weak self] in
                for delay in [0, 150_000_000, 500_000_000, 1_000_000_000] {
                    if delay == 0 {
                        await Task.yield()
                    } else {
                        try? await Task.sleep(nanoseconds: UInt64(delay))
                    }
                    guard !Task.isCancelled else {
                        return
                    }
                    self?.restorePersistedFrame()
                }

                guard !Task.isCancelled else {
                    return
                }
                self?.isRestoringPersistedFrame = false
                self?.saveCurrentFrame(flush: true)
            }
        }

        private func saveCurrentFrame(flush: Bool = false) {
            guard !isRestoringPersistedFrame else {
                return
            }
            guard let window else {
                return
            }

            WindowFrameRestoration.saveFrame(for: window, machine: observer.machine, flush: flush)
        }

        private func saveCurrentFrameSoon() {
            guard !isRestoringPersistedFrame else {
                return
            }

            saveCurrentFrame()
            deferredSaveTask?.cancel()
            deferredSaveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else {
                    return
                }
                self?.saveCurrentFrame(flush: true)
            }
        }

        private func updateFullScreenState() {
            setFullScreen(window?.styleMask.contains(.fullScreen) == true)
        }

        private func setFullScreen(_ active: Bool) {
            if observer.isFullScreen != active {
                observer.isFullScreen = active
            }

            if active {
                if previousToolbarVisibility == nil {
                    previousToolbarVisibility = window?.toolbar?.isVisible ?? true
                }
                if previousAcceptsMouseMovedEvents == nil {
                    previousAcceptsMouseMovedEvents = window?.acceptsMouseMovedEvents ?? false
                }
                window?.acceptsMouseMovedEvents = true
                updateWindowChrome()
            } else {
                if let previousToolbarVisibility {
                    window?.toolbar?.isVisible = previousToolbarVisibility
                } else {
                    window?.toolbar?.isVisible = true
                }
                if let previousAcceptsMouseMovedEvents {
                    window?.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
                }
                previousToolbarVisibility = nil
                previousAcceptsMouseMovedEvents = nil
                setTopChromeActive(false)
                setBottomChromeActive(false)
            }
        }

        private func handleMouseMoved(_ event: NSEvent) {
            guard observer.isFullScreen,
                  let window,
                  event.window === window,
                  let contentView = window.contentView else {
                return
            }

            let location = contentView.convert(event.locationInWindow, from: nil)
            let bounds = contentView.bounds
            let nearTop = location.y >= bounds.maxY - revealThreshold
            let nearBottom = location.y <= bounds.minY + revealThreshold

            setTopChromeActive(nearTop)
            setBottomChromeActive(nearBottom)
        }

        private func setTopChromeActive(_ active: Bool) {
            if observer.topChromeActive != active {
                observer.topChromeActive = active
            }
            updateWindowChrome()
        }

        private func setBottomChromeActive(_ active: Bool) {
            if observer.bottomChromeActive != active {
                observer.bottomChromeActive = active
            }
        }

        private func updateWindowChrome() {
            guard observer.isFullScreen else {
                updateContentLayoutTopInsetSoon()
                return
            }

            window?.toolbar?.isVisible = observer.topChromeActive
            updateContentLayoutTopInsetSoon()
        }

        private func updateContentLayoutTopInsetSoon() {
            updateContentLayoutTopInset()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.updateContentLayoutTopInset()
                }
            }
        }

        private func updateContentLayoutTopInset() {
            guard let window,
                  let contentView = window.contentView else {
                setContentLayoutTopInset(0)
                return
            }

            let layoutRect = contentView.convert(window.contentLayoutRect, from: nil)
            let topInset = max(0, contentView.bounds.maxY - layoutRect.maxY)
            setContentLayoutTopInset(topInset)
        }

        private func setContentLayoutTopInset(_ inset: CGFloat) {
            guard abs(observer.contentLayoutTopInset - inset) > 0.5 else {
                return
            }

            observer.contentLayoutTopInset = inset
        }
    }
}

private struct AspectResizeState {
    enum DrivingDimension {
        case width
        case height
    }

    let displayAspectRatio: CGFloat
    let drivingDimension: DrivingDimension
    let widthOutsideDisplay: CGFloat
}

private final class WindowResizeAspectRatioDelegate: NSObject, NSWindowDelegate {
    weak var coordinator: WindowChromeObserver.Coordinator?
    weak var fallback: (any NSWindowDelegate)?

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let fallbackSize = fallback?.windowWillResize?(sender, to: frameSize) ?? frameSize
        return coordinator?.frameSize(for: sender,
                                      proposedFrameSize: fallbackSize) ?? fallbackSize
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        }

        return (fallback as AnyObject?)?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        guard let fallbackObject = fallback as AnyObject?,
              fallbackObject.responds(to: aSelector) else {
            return super.forwardingTarget(for: aSelector)
        }

        return fallbackObject
    }
}

private final class WindowChromeObserverView: NSView {
    weak var coordinator: WindowChromeObserver.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: window)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull && !isInfinite else {
            return 0
        }

        return width * height
    }
}

private struct ToolbarIconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(title)
    }
}

private struct SoundToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var showingVolumePopover = false

    var body: some View {
        HStack(spacing: 8) {
            if emulator.machine.capabilities.supportsSIDModelSelection {
                Picker("SID", selection: $emulator.sidModel) {
                    ForEach(EmulatorSession.SIDModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
                .help("SID model")
            }

            Button {
                showingVolumePopover.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: volumeSymbol)
                    Text("\(emulator.soundVolume)%")
                        .monospacedDigit()
                }
            }
            .help("Master volume")
            .popover(isPresented: $showingVolumePopover, arrowEdge: .bottom) {
                VolumePopoverContent(soundEnabled: $emulator.soundEnabled,
                                     volume: volumeBinding)
            }
            .frame(width: 78)
        }
        .fixedSize()
    }

    private var volumeSymbol: String {
        if !emulator.soundEnabled || emulator.soundVolume == 0 {
            return "speaker.slash.fill"
        }

        if emulator.soundVolume < 45 {
            return "speaker.wave.1.fill"
        }

        return "speaker.wave.2.fill"
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(emulator.soundVolume)
        } set: { value in
            emulator.soundVolume = Int(value.rounded())
        }
    }
}

private struct VolumePopoverContent: View {
    @Binding var soundEnabled: Bool
    @Binding var volume: Double

    var body: some View {
        VStack(spacing: 10) {
            Button {
                soundEnabled.toggle()
            } label: {
                Label(soundEnabled ? "Mute" : "Unmute",
                      systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(soundEnabled ? "Mute audio" : "Unmute audio")

            VerticalVolumeSlider(value: $volume, range: 0...100)
                .frame(width: 38, height: 132)
                .disabled(!soundEnabled)
                .accessibilityLabel("Master volume")

            Text("\(Int(volume.rounded()))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 86)
    }
}

private struct VerticalVolumeSlider: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var value: Double

    let range: ClosedRange<Double>

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value,
                              minValue: range.lowerBound,
                              maxValue: range.upperBound,
                              target: context.coordinator,
                              action: #selector(Coordinator.valueChanged(_:)))
        slider.isContinuous = true
        slider.isVertical = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.value = $value
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.isEnabled = isEnabled
        slider.isVertical = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false

        if abs(slider.doubleValue - value) > 0.5 {
            slider.doubleValue = value
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    @MainActor
    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

private struct RAMExpansionStatusChip: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "memorychip")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(activityColor)
                .symbolRenderingMode(.hierarchical)

            Text(emulator.ramExpansion.chipTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.13), in: Capsule())
        .help(helpText)
    }

    private var activityColor: Color {
        .secondary.opacity(0.55)
    }

    private var helpText: String {
        "\(emulator.ramExpansion.displayTitle(for: emulator.machine)) configured"
    }
}

private struct CartridgeIndicator: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(emulator.cartridgeStatus.isAttached ? .green : Color.secondary.opacity(0.32))
                    .frame(width: 8, height: 8)
                    .shadow(color: emulator.cartridgeStatus.isAttached ? .green.opacity(0.45) : .clear,
                            radius: 4)

                Image(systemName: "memorychip")
                    .foregroundStyle(.secondary)

                Text("Cart")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(isPresented ? Color.secondary.opacity(0.18) : Color.clear, in: Capsule())
        .help(emulator.cartridgeStatus.isAttached ? "Cartridge attached" : "No cartridge attached")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CartridgePopover(isPresented: $isPresented)
        }
    }
}

private struct CartridgePopover: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "memorychip")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cartridge")
                        .font(.headline)
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                VMCInfoRow("Image") {
                    Text(imageTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                VMCInfoRow("Type") {
                    Text(typeTitle)
                        .lineLimit(1)
                }

                VMCInfoRow("Class") {
                    Text(classTitle)
                        .lineLimit(1)
                }

                VMCInfoRow("ROM") {
                    Text(romTitle)
                        .lineLimit(1)
                }

                VMCInfoRow("Banks") {
                    Text(bankTitle)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    emulator.detachCartridge()
                    isPresented = false
                } label: {
                    Label("Detach", systemImage: "eject")
                }
                .disabled(!emulator.cartridgeStatus.isAttached)

                Button {
                    openCartridgePanel()
                } label: {
                    Label(emulator.cartridgeStatus.isAttached ? "Replace..." : "Attach...",
                          systemImage: "memorychip")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var statusTitle: String {
        emulator.cartridgeStatus.isAttached ? "Attached" : "No cartridge attached"
    }

    private var imageTitle: String {
        guard let imagePath = emulator.cartridgeStatus.imagePath,
              !imagePath.isEmpty else {
            return "No image"
        }

        return URL(fileURLWithPath: imagePath).lastPathComponent
    }

    private var typeTitle: String {
        if let cartridgeName = emulator.cartridgeStatus.cartridgeName,
           !cartridgeName.isEmpty {
            return cartridgeName
        }

        return emulator.cartridgeStatus.isAttached ? "Cartridge" : "None"
    }

    private var classTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        let flags = emulator.cartridgeStatus.cartridgeFlags
        var classes: [String] = []

        if flags & CartridgeInfoFlag.game != 0 {
            classes.append("Game")
        }
        if flags & CartridgeInfoFlag.freezer != 0 {
            classes.append("Freezer")
        }
        if flags & CartridgeInfoFlag.utility != 0 {
            classes.append("Utility")
        }
        if flags & CartridgeInfoFlag.ramExpansion != 0 {
            classes.append("RAM expansion")
        }
        if flags & CartridgeInfoFlag.generic != 0 {
            classes.append("Generic")
        }

        return classes.isEmpty ? "Cartridge" : classes.joined(separator: ", ")
    }

    private var romTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        guard emulator.cartridgeStatus.romSize > 0 else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(emulator.cartridgeStatus.romSize),
                                         countStyle: .memory)
    }

    private var bankTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        let bankCount = emulator.cartridgeStatus.bankCount
        let chipCount = emulator.cartridgeStatus.chipCount
        guard bankCount > 0 else {
            return "Unknown"
        }

        let bankUnit = bankCount == 1 ? "bank" : "banks"
        let chipUnit = chipCount == 1 ? "chip" : "chips"
        return "\(bankCount) \(bankUnit), \(chipCount) \(chipUnit)"
    }

    private func openCartridgePanel() {
        let panel = NSOpenPanel()
        panel.title = "Attach Cartridge"
        panel.message = "Choose a CRT cartridge image."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.cartridgeImageTypes

        isPresented = false
        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachCartridge(url: url)
    }

    private static let cartridgeImageTypes: [UTType] = {
        let types = ["crt"].compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.data] : types
    }()
}

private enum CartridgeInfoFlag {
    static let generic: UInt32 = 0x0001
    static let ramExpansion: UInt32 = 0x0002
    static let freezer: UInt32 = 0x0004
    static let game: UInt32 = 0x0008
    static let utility: UInt32 = 0x0010
}

#Preview {
    ContentView()
        .environmentObject(EmulatorSession())
        .environmentObject(AIAssistantSettings())
        .environmentObject(AIDocumentLibraryStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("ViceMacPreviewAIDocuments", isDirectory: true)))
        .environmentObject(QLinkReloadedService())
}

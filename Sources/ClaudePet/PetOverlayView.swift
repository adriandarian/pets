import AppKit
import ClaudePetCore
import QuartzCore
import SwiftUI

private enum PetOverlayMetrics {
    static let chatBubbleScale: CGFloat = 0.86
    static let petScale: CGFloat = 0.72
    static let sessionBubbleMaxWidth: CGFloat = 370
    static let visibleSessionRowLimit = 3
    static let scrollableSessionStackMaxHeight: CGFloat = 250
    static let scrollableSessionContentBleed: CGFloat = 12
    static let spriteSize: CGFloat = 132
    static let chatControlSize: CGFloat = 50
    static let expandedChatControlSize: CGFloat = chatControlSize * 0.75
    static let collapsedChatBadgeSize: CGFloat = expandedChatControlSize
    static let collapsedChatBadgeFontSize: CGFloat = 15
    static let collapsedChatBadgeCondensedFontSize: CGFloat = 13
    static let petContainerWidth: CGFloat = 152
    static let petContainerHeight: CGFloat = 146
}

private enum PetOverlayPalette {
    static let controlFill = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 20.0 / 255.0)
    static let sessionFill = Color(red: 24.0 / 255.0, green: 24.0 / 255.0, blue: 24.0 / 255.0)
    static let overflowFill = sessionFill
    static let codexGreen = Color(red: 107.0 / 255.0, green: 198.0 / 255.0, blue: 127.0 / 255.0)
    static let codexGreenText = Color(red: 0.035, green: 0.14, blue: 0.075)
    static let idleEyeGreen = Color(red: 0.52, green: 0.82, blue: 0.56)
}

struct PetOverlayView: View {
    @ObservedObject var store: ClaudePetStore
    let petInstanceID: PetInstance.ID
    @State private var areChatsExpanded = true
    @State private var isPetHovered = false

    var body: some View {
        Group {
            if let petInstance {
                ZStack(alignment: overlayAlignment) {
                    Color.clear

                    VStack(alignment: stackHorizontalAlignment, spacing: 6) {
                        if areChatsExpanded {
                            SessionBubble(
                                store: store,
                                contextLineCount: petInstance.sessionContextLineCount
                            )
                                .frame(maxWidth: PetOverlayMetrics.sessionBubbleMaxWidth)
                                .scaleEffect(PetOverlayMetrics.chatBubbleScale, anchor: scaleAnchor)
                                .frame(
                                    width: PetOverlayMetrics.sessionBubbleMaxWidth * PetOverlayMetrics.chatBubbleScale,
                                    alignment: frameAlignment
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        ZStack(alignment: .topTrailing) {
                            PetSprite(
                                petID: petInstance.petID,
                                status: spriteStatus,
                                isExcited: isPetHovered,
                                pixelation: petInstance.pixelation
                            )
                                .id(petInstance.pixelation)
                                .frame(width: PetOverlayMetrics.spriteSize, height: PetOverlayMetrics.spriteSize)
                                .scaleEffect(PetOverlayMetrics.petScale)
                                .frame(
                                    width: PetOverlayMetrics.spriteSize * PetOverlayMetrics.petScale,
                                    height: PetOverlayMetrics.spriteSize * PetOverlayMetrics.petScale
                                )
                                .scaleEffect(PetHoverExcitement.scale(isHovered: isPetHovered))
                                .offset(y: PetHoverExcitement.verticalOffset(isHovered: isPetHovered))
                                .contentShape(Rectangle())
                                .animation(.spring(response: 0.18, dampingFraction: 0.52), value: isPetHovered)
                                .onHover { hovering in
                                    isPetHovered = petInstance.animationSettings.isHoverBounceEnabled && hovering
                                }
                                .contextMenu {
                                    ForEach(ClaudePetCatalog.builtInPetIDs, id: \.self) { petID in
                                        Button {
                                            store.selectPetInstance(petInstance.id)
                                            store.selectPet(petID)
                                        } label: {
                                            Label(
                                                ClaudePetCatalog.displayName(for: petID),
                                                systemImage: petInstance.petID == petID ? "checkmark" : "face.smiling"
                                            )
                                        }
                                    }
                                }

                            ChatCollapseButton(
                                isExpanded: areChatsExpanded,
                                count: store.collapsedChatCount,
                                status: store.dominantStatus
                            ) {
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    areChatsExpanded.toggle()
                                }
                            }
                            .scaleEffect(PetOverlayMetrics.petScale)
                            .frame(
                                width: (areChatsExpanded
                                    ? PetOverlayMetrics.expandedChatControlSize
                                    : PetOverlayMetrics.chatControlSize) * PetOverlayMetrics.petScale,
                                height: (areChatsExpanded
                                    ? PetOverlayMetrics.expandedChatControlSize
                                    : PetOverlayMetrics.chatControlSize) * PetOverlayMetrics.petScale
                            )
                            .offset(x: 13, y: -5)
                        }
                        .frame(
                            width: PetOverlayMetrics.petContainerWidth * PetOverlayMetrics.petScale,
                            height: PetOverlayMetrics.petContainerHeight * PetOverlayMetrics.petScale,
                            alignment: .center
                        )
                        .padding(petEdge, 4)
                    }
                    .padding(.bottom, 9)
                    .padding(panelEdge, 13)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 500, height: 360)
    }

    private var petInstance: PetInstance? {
        store.petInstance(for: petInstanceID)
    }

    private var spriteStatus: ClaudeDisplayStatus {
        petInstance?.animationSettings.areStatusMoodsEnabled == true ? store.dominantStatus : .unknown
    }

    private var isLeadingPlacement: Bool {
        petInstance?.overlayPosition.horizontalPlacement == .leading
    }

    private var overlayAlignment: Alignment {
        isLeadingPlacement ? .bottomLeading : .bottomTrailing
    }

    private var stackHorizontalAlignment: HorizontalAlignment {
        isLeadingPlacement ? .leading : .trailing
    }

    private var scaleAnchor: UnitPoint {
        isLeadingPlacement ? .bottomLeading : .bottomTrailing
    }

    private var frameAlignment: Alignment {
        isLeadingPlacement ? .leading : .trailing
    }

    private var petEdge: Edge.Set {
        isLeadingPlacement ? .leading : .trailing
    }

    private var panelEdge: Edge.Set {
        isLeadingPlacement ? .leading : .trailing
    }
}

private struct SessionBubble: View {
    @ObservedObject var store: ClaudePetStore
    let contextLineCount: Int

    var body: some View {
        if let lastError = store.lastError {
            SessionMessageBubble(
                status: .unknown,
                title: "Claude session error",
                message: lastError
            )
        } else if store.sessions.isEmpty {
            SessionMessageBubble(
                status: .unknown,
                title: "Claude sessions",
                message: "No live Claude sessions"
            )
        } else if store.visibleSessions.isEmpty {
            SessionMessageBubble(
                status: .unknown,
                title: "Claude sessions",
                message: "All Claude sessions dismissed"
            )
        } else {
            SessionCardStack(
                sessions: store.visibleSessions,
                visibleRowLimit: PetOverlayMetrics.visibleSessionRowLimit,
                contextLineCount: contextLineCount,
                onActivate: { session in
                    store.activateSession(session)
                },
                onReply: { session, message in
                    store.sendReply(message, to: session)
                },
                onDismiss: { session in
                    store.dismissSession(session)
                }
            )
        }
    }

}

private struct ChatCollapseButton: View {
    let isExpanded: Bool
    let count: Int
    let status: ClaudeDisplayStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isExpanded {
                    ExpandedChatControl()
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                } else {
                    CollapsedChatBadge(count: count, status: status)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .frame(width: controlSize, height: controlSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse chats" : "Expand chats")
        .accessibilityValue(isExpanded ? "Expanded" : "\(count) chats")
    }

    private var controlSize: CGFloat {
        isExpanded ? PetOverlayMetrics.expandedChatControlSize : PetOverlayMetrics.chatControlSize
    }
}

private struct ExpandedChatControl: View {
    private let controlSize = PetOverlayMetrics.expandedChatControlSize
    private let circleSize = PetOverlayMetrics.expandedChatControlSize - 2

    var body: some View {
        ZStack {
            Circle()
                .fill(PetOverlayPalette.controlFill.opacity(0.98))
                .frame(width: circleSize, height: circleSize)
                .overlay(Circle().stroke(Color.white.opacity(0.13), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.36), radius: 2, x: 0, y: 1)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.62))
        }
        .frame(width: controlSize, height: controlSize)
    }
}

private struct CollapsedChatBadge: View {
    let count: Int
    let status: ClaudeDisplayStatus

    var body: some View {
        Text("\(count)")
            .font(.system(
                size: count > 99
                    ? PetOverlayMetrics.collapsedChatBadgeCondensedFontSize
                    : PetOverlayMetrics.collapsedChatBadgeFontSize,
                weight: .bold
            ))
            .monospacedDigit()
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: PetOverlayMetrics.collapsedChatBadgeSize, height: PetOverlayMetrics.collapsedChatBadgeSize)
            .background(
                Circle()
                    .fill(statusColor(status))
                    .shadow(color: .black.opacity(0.24), radius: 7, x: 0, y: 3)
            )
    }

    private var foregroundColor: Color {
        switch status {
        case .waiting:
            return Color(red: 0.10, green: 0.08, blue: 0.04)
        case .idle:
            return PetOverlayPalette.codexGreenText
        case .busy, .unknown:
            return Color(red: 0.04, green: 0.045, blue: 0.05)
        }
    }
}

private struct SessionCardStack: View {
    let sessions: [ClaudeSession]
    let visibleRowLimit: Int
    let contextLineCount: Int
    let onActivate: (ClaudeSession) -> Void
    let onReply: (ClaudeSession, String) -> Void
    let onDismiss: (ClaudeSession) -> Void

    @State private var rowMinYValues: [String: CGFloat] = [:]
    @State private var viewportHeight: CGFloat = PetOverlayMetrics.scrollableSessionStackMaxHeight

    var body: some View {
        Group {
            if shouldScroll {
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical) {
                        sessionRows
                            .padding(.top, PetOverlayMetrics.scrollableSessionContentBleed)
                            .padding(.leading, PetOverlayMetrics.scrollableSessionContentBleed)
                            .padding(.bottom, PetOverlayMetrics.scrollableSessionContentBleed)
                            .background(HiddenAppKitScrollIndicators())
                    }
                    .coordinateSpace(name: Self.scrollCoordinateSpace)
                    .frame(maxHeight: PetOverlayMetrics.scrollableSessionStackMaxHeight, alignment: .top)
                    .contentShape(Rectangle())
                    .background(viewportHeightReader)
                    .overlay(SessionScrollWheelCapture())
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .onPreferenceChange(SessionRowMinYPreferenceKey.self) { values in
                        rowMinYValues = values
                    }
                    .onPreferenceChange(SessionViewportHeightPreferenceKey.self) { height in
                        viewportHeight = height
                    }

                    if remainingOverflowCount > 0 {
                        OverflowBadge(count: remainingOverflowCount)
                            .padding(.bottom, 2)
                            .zIndex(1)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                sessionRows
            }
        }
    }

    private static let scrollCoordinateSpace = "SessionCardStackScroll"

    private var shouldScroll: Bool {
        sessions.count > visibleRowLimit
    }

    private var remainingOverflowCount: Int {
        if rowMinYValues.isEmpty {
            return max(0, sessions.count - visibleRowLimit)
        }

        return PetOverflowBadgeVisibility.remainingBelowViewport(
            rowMinYValues: sessions.compactMap { rowMinYValues[$0.id] },
            viewportHeight: viewportHeight
        )
    }

    private var viewportHeightReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SessionViewportHeightPreferenceKey.self,
                value: proxy.size.height
            )
        }
    }

    private var sessionRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                SessionRow(session: session, contextLineCount: contextLineCount) {
                    onActivate(session)
                } onReply: { message in
                    onReply(session, message)
                } onDismiss: {
                    onDismiss(session)
                }
                .background(rowMinYReader(for: session.id))
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
    }

    private func rowMinYReader(for id: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: SessionRowMinYPreferenceKey.self,
                value: [id: proxy.frame(in: .named(Self.scrollCoordinateSpace)).minY]
            )
        }
    }
}

private struct SessionRowMinYPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct SessionViewportHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = PetOverlayMetrics.scrollableSessionStackMaxHeight

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct HiddenAppKitScrollIndicators: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureEnclosingScrollView(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureEnclosingScrollView(from: nsView)
    }

    private func configureEnclosingScrollView(from view: NSView) {
        [0.0, 0.05, 0.2, 0.6].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                hideEnclosingScrollIndicators(from: view)
            }
        }
    }

    private func hideEnclosingScrollIndicators(from view: NSView) {
        guard let scrollView = enclosingScrollView(from: view) else { return }
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScroller?.isHidden = true
        scrollView.horizontalScroller?.isHidden = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.drawsBackground = false
    }

    private func enclosingScrollView(from view: NSView) -> NSScrollView? {
        var candidate: NSView? = view
        while let current = candidate {
            if let scrollView = current as? NSScrollView {
                return scrollView
            }
            if let scrollView = current.enclosingScrollView {
                return scrollView
            }
            candidate = current.superview
        }
        return nil
    }
}

private struct SessionScrollWheelCapture: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ScrollWheelCaptureView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ScrollWheelCaptureView: NSView {
        override var isOpaque: Bool {
            false
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard NSApp.currentEvent?.type == .scrollWheel,
                  !isHidden,
                  alphaValue > 0,
                  bounds.contains(point)
            else {
                return nil
            }

            return self
        }

        override func scrollWheel(with event: NSEvent) {
            guard let scrollView = scrollView(at: event.locationInWindow) else {
                super.scrollWheel(with: event)
                return
            }

            scrollView.scrollWheel(with: event)
        }

        private func scrollView(at windowPoint: NSPoint) -> NSScrollView? {
            guard let contentView = window?.contentView else { return nil }
            return descendantScrollView(in: contentView, at: windowPoint)
        }

        private func descendantScrollView(in view: NSView, at windowPoint: NSPoint) -> NSScrollView? {
            for subview in view.subviews.reversed() {
                guard !subview.isHidden, subview.alphaValue > 0 else { continue }

                if let scrollView = subview as? NSScrollView {
                    let pointInScrollView = scrollView.convert(windowPoint, from: nil)
                    if scrollView.bounds.contains(pointInScrollView) {
                        return scrollView
                    }
                }

                if let scrollView = descendantScrollView(in: subview, at: windowPoint) {
                    return scrollView
                }
            }

            return nil
        }
    }
}

private struct SessionMessageBubble: View {
    let status: ClaudeDisplayStatus
    let title: String
    let message: String
    private let cornerRadius: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(PetSessionContextLineCount.defaultValue)
        }
        .padding(.trailing, 34)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PetOverlayPalette.sessionFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    SessionBubbleTopHighlight(cornerRadius: cornerRadius)
                }
        )
        .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
        .overlay(alignment: .topTrailing) {
            SessionStatusIndicator(status: status)
                .padding(14)
        }
    }
}

private struct OverflowBadge: View {
    let count: Int

    var body: some View {
        Text(PetBadgeLabel.overflowCount(count))
            .font(.system(size: count > 99 ? 13 : 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(Color.white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 54, height: 28)
            .background(
                Capsule()
                    .fill(PetOverlayPalette.overflowFill)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.34), radius: 7, x: 0, y: 3)
            )
    }
}

private struct SessionRow: View {
    let session: ClaudeSession
    let contextLineCount: Int
    let onActivate: () -> Void
    let onReply: (String) -> Void
    let onDismiss: () -> Void
    private let cornerRadius: CGFloat = 26

    @State private var isReplying = false
    @State private var isHovered = false
    @State private var shouldSuppressNextActivation = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(contextLineCount)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, titleTrailingPadding)

                VStack(alignment: .trailing, spacing: 2) {
                    SessionStatusIndicator(status: session.displayStatus)

                    if shouldShowReplyButton {
                        Button("Reply") {
                            suppressRowActivation()
                            isReplying = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    }
                }
                .animation(.easeOut(duration: 0.12), value: shouldShowReplyButton)
            }

            if isReplying {
                replyEditor
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PetOverlayPalette.sessionFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    SessionBubbleTopHighlight(cornerRadius: cornerRadius)
                }
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onTapGesture {
            guard !shouldSuppressNextActivation else {
                shouldSuppressNextActivation = false
                return
            }
            guard !isReplying else { return }
            onActivate()
        }
        .overlay(alignment: .topLeading) {
            if isHovered {
                DismissSessionButton {
                    suppressRowActivation()
                    onDismiss()
                }
                    .offset(x: -5, y: -8)
                    .transition(.opacity.combined(with: .scale(scale: 0.86)))
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var subtitle: String {
        session.chatPreview ?? "No chat preview yet"
    }

    private var shouldShowReplyButton: Bool {
        session.replyTarget != nil && isHovered && !isReplying
    }

    private var titleTrailingPadding: CGFloat {
        PetReplyControlPlacement.titleTrailingPadding(replyButtonVisible: shouldShowReplyButton)
    }

    private var replyEditor: some View {
        HStack(spacing: 7) {
            replyTextField
            replySubmitButton
        }
    }

    private var replyTextField: some View {
        TextField(replyPlaceholder, text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1...3)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(replyFieldBackground)
            .onSubmit(sendReply)
            .onExitCommand(perform: cancelReply)
    }

    private var replySubmitButton: some View {
        Button("Reply") {
            suppressRowActivation()
            sendReply()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Color(red: 0.04, green: 0.045, blue: 0.05))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(statusColor(session.displayStatus)))
    }

    private var replyFieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var replyPlaceholder: String {
        "Reply to \(session.title)"
    }

    private func suppressRowActivation() {
        shouldSuppressNextActivation = true
    }

    private func cancelReply() {
        draft = ""
        isReplying = false
    }

    private func sendReply() {
        let message = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        onReply(draft)
        draft = ""
        isReplying = false
    }
}

private struct SessionBubbleTopHighlight: View {
    let cornerRadius: CGFloat

    var body: some View {
        LinearGradient(
            colors: [
                .white.opacity(0.0),
                .white.opacity(0.30),
                .white.opacity(0.30),
                .white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.horizontal, cornerRadius * 0.72)
        .padding(.top, 1)
    }
}

private struct DismissSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.24, green: 0.24, blue: 0.25))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color(red: 0.78, green: 0.78, blue: 0.80))
                        .overlay(Circle().stroke(Color.white.opacity(0.84), lineWidth: 1))
                        .shadow(color: .black.opacity(0.30), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss session")
    }
}

private struct SessionStatusIndicator: View {
    let status: ClaudeDisplayStatus

    var body: some View {
        if status.isRunning {
            RunningStatusSpinner()
                .frame(width: 18, height: 18)
                .accessibilityLabel("Running")
        } else {
            ZStack {
                Circle()
                    .fill(statusFill)
                    .frame(width: 24, height: 24)

                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(symbolColor)
            }
            .accessibilityLabel(status.rawValue)
        }
    }

    private var symbolName: String {
        switch status {
        case .busy:
            return "arrow.triangle.2.circlepath"
        case .waiting:
            return "exclamationmark"
        case .idle:
            return "checkmark"
        case .unknown:
            return "questionmark"
        }
    }

    private var statusFill: Color {
        switch status {
        case .busy:
            return statusColor(status).opacity(0.18)
        case .waiting:
            return statusColor(status).opacity(0.92)
        case .idle:
            return PetOverlayPalette.codexGreen
        case .unknown:
            return Color.white.opacity(0.12)
        }
    }

    private var symbolColor: Color {
        switch status {
        case .waiting:
            return Color(red: 0.10, green: 0.08, blue: 0.04)
        case .idle:
            return Color(red: 0.05, green: 0.18, blue: 0.09)
        case .busy:
            return statusColor(status)
        case .unknown:
            return .white.opacity(0.62)
        }
    }
}

private struct RunningStatusSpinner: View {
    private static let frameInterval = 1.0 / 12.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.frameInterval)) { timeline in
            spinner(rotation: timeline.date.timeIntervalSinceReferenceDate * 360 / 0.85)
        }
    }

    private func spinner(rotation: Double) -> some View {
        Circle()
            .trim(from: 0.12, to: 0.86)
            .stroke(
                Color.white.opacity(0.72),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            .rotationEffect(.degrees(rotation))
    }
}

struct PetSprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    let pixelation: PetSpritePixelation

    var body: some View {
        Group {
            if ClaudePetCatalog.category(for: petID)?.id == "cloud-pets" {
                CloudFamilySprite(
                    petID: petID,
                    status: status,
                    isExcited: isExcited
                )
            } else {
                switch ClaudePetCatalog.category(for: petID)?.id {
                case "workspace-pets":
                    WorkspacePetSprite(petID: petID, status: status, isExcited: isExcited)
                case "nature-pets":
                    NaturePetSprite(petID: petID, status: status, isExcited: isExcited)
                case "cozy-pets":
                    CozyPetSprite(petID: petID, status: status, isExcited: isExcited)
                default:
                    WorkspacePetSprite(petID: .codeBot, status: status, isExcited: isExcited)
                }
            }
        }
        .pixelatedSpriteEffect(pixelation)
    }
}

private struct CloudFamilySprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    private static let animationFrameInterval = 1.0 / 12.0
    private static let staticDate = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        if PetHoverExcitement.usesContinuousSpriteMotion(status: status, isHovered: isExcited) {
            TimelineView(.periodic(from: .now, by: Self.animationFrameInterval)) { timeline in
                ScaledCloudFamilySprite(
                    petID: petID,
                    status: status,
                    isExcited: isExcited,
                    date: timeline.date
                )
            }
        } else {
            ScaledCloudFamilySprite(
                petID: petID,
                status: status,
                isExcited: isExcited,
                date: Self.staticDate
            )
        }
    }
}

private struct ScaledCloudFamilySprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    let date: Date

    private var seconds: Double {
        date.timeIntervalSinceReferenceDate
    }

    private var bounce: CGFloat {
        if isExcited {
            return wave(speed: 8.0, amplitude: 6.0)
        }

        switch status {
        case .busy:
            return wave(speed: 4.2, amplitude: 2.0)
        case .waiting:
            return wave(speed: 5.4, amplitude: 3.8)
        case .idle:
            return wave(speed: 1.8, amplitude: 1.0)
        case .unknown:
            return wave(speed: 1.4, amplitude: 0.6)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 128

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: 66 * unit, height: 11 * unit)
                    .offset(y: 35 * unit)

                ZStack {
                    cloudLobe(width: 40 * unit, height: 40 * unit)
                        .offset(x: -24 * unit, y: 2 * unit)
                    cloudLobe(width: 48 * unit, height: 48 * unit)
                        .offset(x: -4 * unit, y: -16 * unit)
                    cloudLobe(width: 42 * unit, height: 42 * unit)
                        .offset(x: 22 * unit, y: -6 * unit)
                    cloudBase(unit: unit)
                        .offset(y: 10 * unit)

                    eyes(unit: unit)
                        .offset(y: 10 * unit)

                    legs(unit: unit)
                        .offset(y: 34 * unit)
                }
                .offset(y: bounce * unit)
                .rotationEffect(.degrees(isExcited ? Double(wave(speed: 5.0, amplitude: 3.2)) : 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cloudLobe(width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(spriteFill)
            .frame(width: width, height: height)
    }

    private func cloudBase(unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 18 * unit, style: .continuous)
            .fill(spriteFill)
            .frame(width: 72 * unit, height: 38 * unit)
    }

    private func eyes(unit: CGFloat) -> some View {
        HStack(spacing: 17 * unit) {
            eye(unit: unit)
            eye(unit: unit)
        }
    }

    private func eye(unit: CGFloat) -> some View {
        Capsule()
            .fill(Color(red: 0.04, green: 0.10, blue: 0.12))
            .frame(width: 7 * unit, height: status == .idle ? 4 * unit : 7 * unit)
    }

    private func legs(unit: CGFloat) -> some View {
        HStack(spacing: 14 * unit) {
            leg(unit: unit)
            leg(unit: unit)
        }
    }

    private func leg(unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5 * unit, style: .continuous)
            .fill(legFill)
            .frame(width: 12 * unit, height: 22 * unit)
    }

    private var spriteFill: Color {
        switch petID {
        case .classicClaude:
            return Color(red: 0.74, green: 0.88, blue: 0.98)
        case .helperCloud:
            return Color(red: 0.96, green: 0.86, blue: 0.49)
        case .sleepCloud:
            return Color(red: 0.83, green: 0.67, blue: 0.91)
        case .focusCloud:
            return Color(red: 0.70, green: 0.71, blue: 0.99)
        case .cuteCloud:
            return Color(red: 0.98, green: 0.96, blue: 0.91)
        default:
            return Color(red: 0.80, green: 0.90, blue: 0.96)
        }
    }

    private var legFill: Color {
        switch petID {
        case .sleepCloud:
            return Color(red: 0.72, green: 0.54, blue: 0.82)
        case .focusCloud:
            return Color(red: 0.57, green: 0.58, blue: 0.90)
        default:
            return spriteFill.opacity(0.86)
        }
    }

    private func wave(speed: Double, amplitude: CGFloat) -> CGFloat {
        CGFloat(sin(seconds * speed)) * amplitude
    }
}

private struct WorkspacePetSprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 128

            ZStack {
                petShadow(unit: unit)

                switch petID {
                case .terminalCube:
                    terminalCube(unit: unit)
                case .bookstackBuddy:
                    bookstackBuddy(unit: unit)
                case .codeBot:
                    codeBot(unit: unit)
                default:
                    codeBot(unit: unit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExcited ? -4 * unit : 0)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func codeBot(unit: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(statusTint.opacity(0.52))
                .frame(width: 4 * unit, height: 18 * unit)
                .offset(y: -49 * unit)

            Circle()
                .fill(statusTint)
                .frame(width: 9 * unit, height: 9 * unit)
                .offset(y: -61 * unit)

            RoundedRectangle(cornerRadius: 20 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.77, blue: 0.77),
                            Color(red: 0.15, green: 0.40, blue: 0.47)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70 * unit, height: 68 * unit)
                .overlay(
                    RoundedRectangle(cornerRadius: 20 * unit, style: .continuous)
                        .stroke(Color(red: 0.05, green: 0.13, blue: 0.16), lineWidth: 3 * unit)
                )

            RoundedRectangle(cornerRadius: 10 * unit, style: .continuous)
                .fill(Color(red: 0.06, green: 0.12, blue: 0.16))
                .frame(width: 48 * unit, height: 28 * unit)
                .overlay(eyes(unit: unit, color: statusTint))
                .offset(y: -5 * unit)

            HStack(spacing: 34 * unit) {
                botArm(unit: unit)
                botArm(unit: unit)
            }
            .offset(y: 8 * unit)

            HStack(spacing: 20 * unit) {
                botLeg(unit: unit)
                botLeg(unit: unit)
            }
            .offset(y: 43 * unit)
        }
    }

    private func terminalCube(unit: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.11, green: 0.15, blue: 0.19),
                            Color(red: 0.04, green: 0.08, blue: 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 74 * unit, height: 62 * unit)
                .overlay(
                    RoundedRectangle(cornerRadius: 17 * unit, style: .continuous)
                        .stroke(Color(red: 0.38, green: 0.82, blue: 0.73).opacity(0.72), lineWidth: 2 * unit)
                )

            HStack(spacing: 9 * unit) {
                Text(">")
                    .font(.system(size: 21 * unit, weight: .heavy, design: .rounded))
                Capsule()
                    .frame(width: 22 * unit, height: 5 * unit)
            }
            .foregroundStyle(statusTint)
            .offset(y: -6 * unit)

            HStack(spacing: 24 * unit) {
                botLeg(unit: unit)
                botLeg(unit: unit)
            }
            .offset(y: 39 * unit)
        }
    }

    private func bookstackBuddy(unit: CGFloat) -> some View {
        ZStack {
            book(width: 72, height: 20, color: Color(red: 0.92, green: 0.47, blue: 0.42), unit: unit)
                .offset(y: 20 * unit)
            book(width: 66, height: 20, color: Color(red: 0.46, green: 0.67, blue: 0.94), unit: unit)
                .offset(y: 0)
            book(width: 76, height: 22, color: Color(red: 0.96, green: 0.75, blue: 0.36), unit: unit)
                .offset(y: -22 * unit)

            eyes(unit: unit, color: Color(red: 0.06, green: 0.08, blue: 0.09))
                .offset(y: -22 * unit)

            HStack(spacing: 18 * unit) {
                botLeg(unit: unit)
                botLeg(unit: unit)
            }
            .offset(y: 45 * unit)
        }
    }

    private func book(width: CGFloat, height: CGFloat, color: Color, unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
            .fill(color)
            .frame(width: width * unit, height: height * unit)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.58))
                    .frame(width: 5 * unit)
                    .padding(.vertical, 4 * unit)
                    .padding(.leading, 9 * unit)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
                    .stroke(Color.black.opacity(0.20), lineWidth: 1.5 * unit)
            )
    }

    private func botArm(unit: CGFloat) -> some View {
        Capsule()
            .fill(Color(red: 0.18, green: 0.45, blue: 0.49))
            .frame(width: 11 * unit, height: 28 * unit)
    }

    private func botLeg(unit: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4 * unit, style: .continuous)
            .fill(Color(red: 0.12, green: 0.29, blue: 0.34))
            .frame(width: 11 * unit, height: 18 * unit)
    }

    private var statusTint: Color {
        statusColor(status == .unknown ? .idle : status)
    }
}

private struct NaturePetSprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 128

            ZStack {
                petShadow(unit: unit)

                switch petID {
                case .pebblePal:
                    pebblePal(unit: unit)
                case .pocketStar:
                    pocketStar(unit: unit)
                case .sproutBuddy:
                    sproutBuddy(unit: unit)
                default:
                    sproutBuddy(unit: unit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExcited ? -5 * unit : 0)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func sproutBuddy(unit: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.38, green: 0.73, blue: 0.42))
                .frame(width: 9 * unit, height: 42 * unit)
                .offset(y: -20 * unit)

            leaf(unit: unit)
                .rotationEffect(.degrees(-30))
                .offset(x: -18 * unit, y: -42 * unit)
            leaf(unit: unit)
                .rotationEffect(.degrees(32))
                .offset(x: 18 * unit, y: -44 * unit)

            RoundedRectangle(cornerRadius: 18 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.61, green: 0.40, blue: 0.28),
                            Color(red: 0.36, green: 0.22, blue: 0.16)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 70 * unit, height: 46 * unit)
                .offset(y: 18 * unit)

            eyes(unit: unit, color: Color(red: 0.05, green: 0.08, blue: 0.05))
                .offset(y: 13 * unit)
        }
    }

    private func pebblePal(unit: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.74, blue: 0.68),
                            Color(red: 0.43, green: 0.47, blue: 0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 82 * unit, height: 62 * unit)
                .overlay(Ellipse().stroke(Color.black.opacity(0.22), lineWidth: 2 * unit))

            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 18 * unit, height: 12 * unit)
                .offset(x: -18 * unit, y: -18 * unit)

            eyes(unit: unit, color: Color(red: 0.06, green: 0.08, blue: 0.07))
                .offset(y: -2 * unit)
        }
    }

    private func pocketStar(unit: CGFloat) -> some View {
        ZStack {
            star(unit: unit)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.31),
                            Color(red: 0.96, green: 0.48, blue: 0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 82 * unit, height: 82 * unit)
                .shadow(color: statusColor(status).opacity(0.28), radius: 12 * unit)

            eyes(unit: unit, color: Color(red: 0.09, green: 0.08, blue: 0.04))
                .offset(y: 7 * unit)
        }
    }

    private func leaf(unit: CGFloat) -> some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.91, blue: 0.45),
                        Color(red: 0.22, green: 0.58, blue: 0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 34 * unit, height: 22 * unit)
    }

    private func star(unit: CGFloat) -> Path {
        var path = Path()
        let center = CGPoint(x: 41 * unit, y: 41 * unit)
        let points = 5
        let outer = 39 * unit
        let inner = 18 * unit

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = (Double(index) * .pi / Double(points)) - (.pi / 2)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

private struct CozyPetSprite: View {
    let petID: ClaudePetID
    let status: ClaudeDisplayStatus
    let isExcited: Bool

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / 128

            ZStack {
                petShadow(unit: unit)

                switch petID {
                case .nightLamp:
                    nightLamp(unit: unit)
                case .tinyRocket:
                    tinyRocket(unit: unit)
                case .teaCup:
                    teaCup(unit: unit)
                default:
                    teaCup(unit: unit)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: isExcited ? -5 * unit : 0)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func teaCup(unit: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.74, blue: 0.78),
                            Color(red: 0.73, green: 0.38, blue: 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72 * unit, height: 52 * unit)
                .offset(y: 10 * unit)

            Circle()
                .stroke(Color(red: 0.73, green: 0.38, blue: 0.52), lineWidth: 7 * unit)
                .frame(width: 28 * unit, height: 28 * unit)
                .offset(x: 42 * unit, y: 9 * unit)

            steam(unit: unit, x: -16)
            steam(unit: unit, x: 8)

            eyes(unit: unit, color: Color(red: 0.12, green: 0.05, blue: 0.08))
                .offset(y: 6 * unit)
        }
    }

    private func nightLamp(unit: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(statusColor(status).opacity(0.26))
                .frame(width: 92 * unit, height: 92 * unit)

            Path { path in
                path.move(to: CGPoint(x: 42 * unit, y: 22 * unit))
                path.addLine(to: CGPoint(x: 86 * unit, y: 22 * unit))
                path.addLine(to: CGPoint(x: 76 * unit, y: 65 * unit))
                path.addLine(to: CGPoint(x: 52 * unit, y: 65 * unit))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.78, blue: 0.34),
                        Color(red: 0.94, green: 0.42, blue: 0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Capsule()
                .fill(Color(red: 0.42, green: 0.27, blue: 0.32))
                .frame(width: 10 * unit, height: 34 * unit)
                .offset(y: 30 * unit)

            RoundedRectangle(cornerRadius: 6 * unit, style: .continuous)
                .fill(Color(red: 0.34, green: 0.20, blue: 0.24))
                .frame(width: 46 * unit, height: 10 * unit)
                .offset(y: 51 * unit)

            eyes(unit: unit, color: Color(red: 0.11, green: 0.07, blue: 0.05))
                .offset(y: -3 * unit)
        }
    }

    private func tinyRocket(unit: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.95, blue: 0.91),
                            Color(red: 0.58, green: 0.73, blue: 0.95)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 48 * unit, height: 86 * unit)

            Circle()
                .fill(statusColor(status).opacity(0.72))
                .frame(width: 20 * unit, height: 20 * unit)
                .offset(y: -18 * unit)

            HStack(spacing: 34 * unit) {
                rocketFin(unit: unit, flipped: false)
                rocketFin(unit: unit, flipped: true)
            }
            .offset(y: 25 * unit)

            Path { path in
                path.move(to: CGPoint(x: 64 * unit, y: 103 * unit))
                path.addLine(to: CGPoint(x: 50 * unit, y: 78 * unit))
                path.addLine(to: CGPoint(x: 78 * unit, y: 78 * unit))
                path.closeSubpath()
            }
            .fill(Color(red: 1.0, green: 0.60, blue: 0.21).opacity(0.82))
            .offset(y: isExcited ? 4 * unit : 0)

            eyes(unit: unit, color: Color(red: 0.08, green: 0.10, blue: 0.13))
                .offset(y: 10 * unit)
        }
    }

    private func steam(unit: CGFloat, x: CGFloat) -> some View {
        Capsule()
            .stroke(Color.white.opacity(0.42), lineWidth: 3 * unit)
            .frame(width: 14 * unit, height: 28 * unit)
            .rotationEffect(.degrees(16))
            .offset(x: x * unit, y: -33 * unit)
    }

    private func rocketFin(unit: CGFloat, flipped: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 18 * unit, y: 26 * unit))
            path.addLine(to: CGPoint(x: 0, y: 21 * unit))
            path.closeSubpath()
        }
        .fill(Color(red: 0.93, green: 0.30, blue: 0.36))
        .frame(width: 18 * unit, height: 26 * unit)
        .scaleEffect(x: flipped ? -1 : 1, y: 1)
    }
}

private func petShadow(unit: CGFloat) -> some View {
    Ellipse()
        .fill(Color.black.opacity(0.22))
        .frame(width: 68 * unit, height: 11 * unit)
        .offset(y: 47 * unit)
}

private func eyes(unit: CGFloat, color: Color) -> some View {
    HStack(spacing: 15 * unit) {
        Circle()
            .fill(color)
            .frame(width: 7 * unit, height: 7 * unit)
        Circle()
            .fill(color)
            .frame(width: 7 * unit, height: 7 * unit)
    }
}

private extension View {
    @ViewBuilder
    func pixelatedSpriteEffect(_ pixelation: PetSpritePixelation) -> some View {
        if pixelation == .off {
            self
        } else {
            PixelatedSpriteRasterizer(pixelation: pixelation) {
                self
            }
        }
    }
}

private struct PixelatedSpriteRasterizer<Content: View>: NSViewRepresentable {
    let pixelation: PetSpritePixelation
    let content: Content

    init(pixelation: PetSpritePixelation, @ViewBuilder content: () -> Content) {
        self.pixelation = pixelation
        self.content = content()
    }

    func makeNSView(context: Context) -> PixelatedSpriteRasterView<Content> {
        PixelatedSpriteRasterView(rootView: content, pixelation: pixelation)
    }

    func updateNSView(_ nsView: PixelatedSpriteRasterView<Content>, context: Context) {
        nsView.update(rootView: content, pixelation: pixelation)
    }
}

@MainActor
private final class PixelatedSpriteRasterView<Content: View>: NSView {
    private let hostingView: NSHostingView<Content>
    private let imageLayer = CALayer()
    private var snapshotTask: Task<Void, Never>?
    private var pixelation: PetSpritePixelation

    init(rootView: Content, pixelation: PetSpritePixelation) {
        self.hostingView = NSHostingView(rootView: rootView)
        self.pixelation = pixelation
        super.init(frame: .zero)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        snapshotTask?.cancel()
    }

    override var isOpaque: Bool {
        false
    }

    override func layout() {
        super.layout()
        imageLayer.frame = bounds
        hostingView.frame = offscreenHostingFrame()
        renderSnapshotSoon()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopSnapshotLoop()
        } else {
            startSnapshotLoop()
            renderSnapshotSoon()
        }
    }

    func update(rootView: Content, pixelation: PetSpritePixelation) {
        hostingView.rootView = rootView
        self.pixelation = pixelation
        renderSnapshotSoon()
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true

        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .nearest
        imageLayer.minificationFilter = .nearest
        imageLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(imageLayer)

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        addSubview(hostingView)
    }

    private func startSnapshotLoop() {
        guard snapshotTask == nil else { return }
        snapshotTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.renderSnapshot()
                try? await Task.sleep(for: .milliseconds(83))
            }
        }
    }

    private func stopSnapshotLoop() {
        snapshotTask?.cancel()
        snapshotTask = nil
    }

    private func renderSnapshotSoon() {
        DispatchQueue.main.async { [weak self] in
            self?.renderSnapshot()
        }
    }

    private func renderSnapshot() {
        guard bounds.width > 1, bounds.height > 1 else { return }

        hostingView.frame = offscreenHostingFrame()
        hostingView.layoutSubtreeIfNeeded()

        guard let highResolutionBitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return
        }
        highResolutionBitmap.size = hostingView.bounds.size
        hostingView.cacheDisplay(in: hostingView.bounds, to: highResolutionBitmap)

        guard let pixelatedImage = makePixelatedImage(from: highResolutionBitmap) else {
            return
        }
        imageLayer.contents = pixelatedImage
    }

    private func makePixelatedImage(from sourceBitmap: NSBitmapImageRep) -> CGImage? {
        let lowResolutionSize = NSSize(
            width: max(1, floor(bounds.width / CGFloat(pixelation.renderScale))),
            height: max(1, floor(bounds.height / CGFloat(pixelation.renderScale)))
        )
        guard let lowResolutionBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(lowResolutionSize.width),
            pixelsHigh: Int(lowResolutionSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        lowResolutionBitmap.size = lowResolutionSize

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: lowResolutionBitmap) {
            NSGraphicsContext.current = context
            context.imageInterpolation = .none
            NSColor.clear.setFill()
            NSRect(origin: .zero, size: lowResolutionSize).fill()
            sourceBitmap.draw(in: NSRect(origin: .zero, size: lowResolutionSize))
        }
        NSGraphicsContext.restoreGraphicsState()

        return lowResolutionBitmap.cgImage
    }

    private func offscreenHostingFrame() -> NSRect {
        NSRect(
            x: bounds.maxX + 16,
            y: 0,
            width: bounds.width,
            height: bounds.height
        )
    }
}

private struct CuteCloudClaudeSprite: View {
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    private static let animationFrameInterval = 1.0 / 12.0
    private static let staticDate = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        if PetHoverExcitement.usesContinuousSpriteMotion(status: status, isHovered: isExcited) {
            TimelineView(.periodic(from: .now, by: Self.animationFrameInterval)) { timeline in
                AnimatedCuteCloudClaudeSprite(status: status, isExcited: isExcited, date: timeline.date)
            }
        } else {
            AnimatedCuteCloudClaudeSprite(status: status, isExcited: isExcited, date: Self.staticDate)
        }
    }
}

private struct AnimatedCuteCloudClaudeSprite: View {
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    let date: Date

    private var seconds: Double {
        date.timeIntervalSinceReferenceDate
    }

    private var animationProfile: AnimationProfile {
        if isExcited {
            return AnimationProfile(bounceSpeed: 9.2, bounceAmount: 7.2, swaySpeed: 5.2, swayAmount: 3.6, armSpeed: 10.8, armAmount: 24)
        }

        switch status {
        case .busy:
            return AnimationProfile(bounceSpeed: 4.9, bounceAmount: 2.2, swaySpeed: 3.2, swayAmount: 1.8, armSpeed: 7.6, armAmount: 10)
        case .waiting:
            return AnimationProfile(bounceSpeed: 6.3, bounceAmount: 4.0, swaySpeed: 4.5, swayAmount: 3.0, armSpeed: 7.2, armAmount: 18)
        case .idle:
            return AnimationProfile(bounceSpeed: 2.1, bounceAmount: 1.2, swaySpeed: 1.8, swayAmount: 1.1, armSpeed: 2.4, armAmount: 4)
        case .unknown:
            return AnimationProfile(bounceSpeed: 1.6, bounceAmount: 0.8, swaySpeed: 1.5, swayAmount: 0.8, armSpeed: 1.8, armAmount: 3)
        }
    }

    private var bounce: CGFloat {
        wave(speed: animationProfile.bounceSpeed, amplitude: animationProfile.bounceAmount)
    }

    private var sway: Angle {
        .degrees(wave(speed: animationProfile.swaySpeed, amplitude: animationProfile.swayAmount))
    }

    private var blinkAmount: CGFloat {
        let cycle = seconds.truncatingRemainder(dividingBy: 4.6)
        if cycle > 4.34 {
            return 0.18
        }
        return status == .busy ? 0.74 + wave(speed: 10.0, amplitude: 0.10) : 1.0
    }

    var body: some View {
        ZStack {
            statusGlow
            floorShadow

            ZStack {
                backCloud
                    .offset(x: -15, y: -23)

                torso
                    .offset(y: 38)

                arm(x: -38, side: -1)
                arm(x: 38, side: 1)

                leg(x: -17, phase: 0.0)
                leg(x: 17, phase: 0.8)

                head
                    .offset(y: -14)

                if status == .busy {
                    laptop
                        .offset(x: 27, y: 35)
                }
            }
            .rotationEffect(sway)
            .offset(y: bounce)

            sparkle(x: -48, y: -42, delay: 0.0)
            sparkle(x: 45, y: -36, delay: 0.7)
        }
    }

    private var floorShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.26))
            .frame(width: 78 + abs(bounce * 2.0), height: 13 - min(abs(bounce), 5))
            .offset(y: 56)
    }

    private var statusGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [eyeColor.opacity(0.26), eyeColor.opacity(0.0)],
                    center: .center,
                    startRadius: 16,
                    endRadius: 66
                )
            )
            .frame(width: 128, height: 128)
            .scaleEffect(1.0 + pulse(delay: 0.2) * 0.06)
            .opacity(status == .unknown ? 0.35 : 0.86)
    }

    private var backCloud: some View {
        ZStack {
            cloudLobe(width: 36, height: 40, x: -30, y: 13)
            cloudLobe(width: 42, height: 48, x: -6, y: -3)
            cloudLobe(width: 44, height: 46, x: 21, y: 5)
            cloudLobe(width: 34, height: 38, x: 39, y: 24)
        }
        .opacity(0.98)
    }

    private var head: some View {
        ZStack {
            cloudLobe(width: 52, height: 56, x: -33, y: -3)
            cloudLobe(width: 60, height: 58, x: -6, y: -19)
            cloudLobe(width: 55, height: 56, x: 27, y: -14)
            cloudLobe(width: 45, height: 47, x: 43, y: 12)
            cloudLobe(width: 50, height: 50, x: -44, y: 18)

            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.45, blue: 0.95),
                            Color(red: 0.16, green: 0.34, blue: 0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 90, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color(red: 0.03, green: 0.10, blue: 0.32), lineWidth: 3)
                )
                .offset(y: 9)

            faceScreen
                .offset(y: 8)
        }
    }

    private var faceScreen: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.07, green: 0.11, blue: 0.29))
                .frame(width: 68, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.36, green: 0.55, blue: 1.0).opacity(0.45), lineWidth: 1)
                )

            HStack(spacing: 20) {
                leftEye
                rightEye
            }
            .offset(y: -1)
        }
    }

    private var leftEye: some View {
        Group {
            if status == .idle && !isExcited {
                closedEye(rotation: 8)
            } else {
                Text(">")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(eyeColor)
                    .shadow(color: eyeColor.opacity(0.75), radius: 3)
            }
        }
        .frame(width: 15, height: 18)
    }

    private var rightEye: some View {
        Group {
            if status == .idle && !isExcited {
                closedEye(rotation: -8)
            } else if status == .waiting {
                Text("!")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(eyeColor)
                    .shadow(color: eyeColor.opacity(0.75), radius: 3)
            } else {
                Capsule()
                    .fill(eyeColor)
                    .frame(width: 16, height: max(3, 4.5 * blinkAmount))
                    .shadow(color: eyeColor.opacity(0.75), radius: 3)
            }
        }
        .frame(width: 15, height: 18)
    }

    private func closedEye(rotation: Double) -> some View {
        Capsule()
            .fill(eyeColor)
            .frame(width: 16, height: 4)
            .rotationEffect(.degrees(rotation))
            .shadow(color: eyeColor.opacity(0.6), radius: 3)
    }

    private var torso: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.26, green: 0.51, blue: 1.0),
                        Color(red: 0.14, green: 0.31, blue: 0.83)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 54, height: 38)
            .overlay(
                HStack(spacing: 8) {
                    Text(">")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                    Capsule()
                        .fill(.white.opacity(0.76))
                        .frame(width: 16, height: 4)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color(red: 0.03, green: 0.10, blue: 0.32), lineWidth: 3)
            )
    }

    private func arm(x: CGFloat, side: CGFloat) -> some View {
        Capsule()
            .fill(Color(red: 0.20, green: 0.43, blue: 0.96))
            .frame(width: 15, height: 35)
            .overlay(Capsule().stroke(Color(red: 0.03, green: 0.10, blue: 0.32), lineWidth: 3))
            .rotationEffect(
                .degrees((side < 0 ? 14 : -14) + wave(speed: animationProfile.armSpeed, amplitude: animationProfile.armAmount) * Double(side)),
                anchor: UnitPoint(x: side < 0 ? 0.75 : 0.25, y: 0.08)
            )
            .offset(x: x, y: 35 + wave(speed: 3.4, amplitude: 1.2, phaseOffset: side > 0 ? 0.5 : 0))
    }

    private func leg(x: CGFloat, phase: Double) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(red: 0.18, green: 0.39, blue: 0.94))
            .frame(width: 17, height: 25)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.03, green: 0.10, blue: 0.32), lineWidth: 3)
            )
            .rotationEffect(.degrees(wave(speed: animationProfile.bounceSpeed, amplitude: 4.0, phaseOffset: phase)))
            .offset(x: x, y: 55 + wave(speed: animationProfile.bounceSpeed, amplitude: 1.7, phaseOffset: phase))
    }

    private var laptop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.10, green: 0.15, blue: 0.40))
                .frame(width: 50, height: 39)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color(red: 0.03, green: 0.08, blue: 0.22), lineWidth: 3)
                )

            Text(">")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(eyeColor)
                .shadow(color: eyeColor.opacity(0.65), radius: 3)
        }
        .rotationEffect(.degrees(-4))
    }

    private func cloudLobe(width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        CloudLobe(width: width, height: height)
            .offset(x: x, y: y)
    }

    private func sparkle(x: CGFloat, y: CGFloat, delay: Double) -> some View {
        let pulse = pulse(delay: delay)

        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.72))
                .frame(width: 3, height: 12)
            Capsule()
                .fill(Color.white.opacity(0.72))
                .frame(width: 12, height: 3)
        }
        .scaleEffect(0.55 + pulse * 0.34)
        .opacity(isExcited ? 0.36 + pulse * 0.42 : 0.0)
        .rotationEffect(.degrees(wave(speed: 2.4, amplitude: 14, phaseOffset: delay)))
        .offset(x: x, y: y)
    }

    private var eyeColor: Color {
        switch status {
        case .busy:
            return Color(red: 0.53, green: 0.95, blue: 1.0)
        case .waiting:
            return Color(red: 1.0, green: 0.88, blue: 0.36)
        case .idle:
            return Color(red: 0.54, green: 0.94, blue: 1.0)
        case .unknown:
            return Color.white.opacity(0.66)
        }
    }

    private func wave(speed: Double, amplitude: CGFloat, phaseOffset: Double = 0) -> CGFloat {
        CGFloat(sin(seconds * speed + phaseOffset)) * amplitude
    }

    private func pulse(delay: Double) -> CGFloat {
        let value = sin(seconds * 4.2 + delay)
        return CGFloat((value + 1.0) / 2.0)
    }
}

private struct CloudLobe: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            Ellipse()
                .fill(fill)

            Ellipse()
                .stroke(Color(red: 0.03, green: 0.10, blue: 0.32), lineWidth: 3)

            highlight
        }
        .frame(width: width, height: height)
    }

    private var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.49, green: 0.67, blue: 1.0),
                Color(red: 0.28, green: 0.48, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var highlight: some View {
        Ellipse()
            .fill(Color.white.opacity(0.18))
            .frame(width: width * 0.45, height: height * 0.22)
            .blur(radius: 1.2)
            .offset(x: -width * 0.12, y: -height * 0.24)
    }
}

private struct ClaudeSprite: View {
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    private static let animationFrameInterval = 1.0 / 12.0
    private static let staticDate = Date(timeIntervalSinceReferenceDate: 0)

    var body: some View {
        if PetHoverExcitement.usesContinuousSpriteMotion(status: status, isHovered: isExcited) {
            TimelineView(.periodic(from: .now, by: Self.animationFrameInterval)) { timeline in
                AnimatedClaudeSprite(status: status, isExcited: isExcited, date: timeline.date)
            }
        } else {
            AnimatedClaudeSprite(status: status, isExcited: isExcited, date: Self.staticDate)
        }
    }
}

private struct AnimatedClaudeSprite: View {
    let status: ClaudeDisplayStatus
    let isExcited: Bool
    let date: Date

    private var seconds: Double {
        date.timeIntervalSinceReferenceDate
    }

    private var bounce: CGFloat {
        wave(speed: animationProfile.bounceSpeed, amplitude: animationProfile.bounceAmount)
    }

    private var sway: Angle {
        .degrees(wave(speed: animationProfile.swaySpeed, amplitude: animationProfile.swayAmount))
    }

    private var blinkAmount: CGFloat {
        let cycle = seconds.truncatingRemainder(dividingBy: 4.2)
        if cycle > 3.94 {
            return 0.16
        }
        if status == .busy {
            return 0.82 + wave(speed: 11.0, amplitude: 0.12)
        }
        return 1.0
    }

    var body: some View {
        ZStack {
            statusGlow
            bodyShadow

            ZStack {
                antenna
                    .offset(y: -44)

                sideFin(x: -51, rotation: -17)
                sideFin(x: 51, rotation: 17)

                arm(x: -37, side: -1)
                arm(x: 37, side: 1)

                VStack(spacing: 0) {
                    face
                        .offset(y: 8)
                    torso
                        .offset(y: -4)
                }

                leg(x: -19, stepOffset: -0.6)
                leg(x: 19, stepOffset: 0.6)
            }
            .rotationEffect(sway)
            .offset(y: bounce)

            sparkle(x: -54, y: -36, delay: 0.0)
            sparkle(x: 53, y: -24, delay: 0.55)
            if isExcited {
                sparkle(x: 4, y: -55, delay: 1.1)
            }
        }
    }

    private var animationProfile: AnimationProfile {
        if isExcited {
            return AnimationProfile(bounceSpeed: 7.2, bounceAmount: 5.6, swaySpeed: 5.4, swayAmount: 5.0, armSpeed: 10.5, armAmount: 30)
        }

        switch status {
        case .busy:
            return AnimationProfile(bounceSpeed: 4.8, bounceAmount: 3.0, swaySpeed: 2.8, swayAmount: 2.5, armSpeed: 8.8, armAmount: 16)
        case .waiting:
            return AnimationProfile(bounceSpeed: 5.6, bounceAmount: 4.6, swaySpeed: 4.0, swayAmount: 4.2, armSpeed: 6.8, armAmount: 28)
        case .idle:
            return AnimationProfile(bounceSpeed: 2.4, bounceAmount: 2.0, swaySpeed: 1.7, swayAmount: 1.8, armSpeed: 2.0, armAmount: 6)
        case .unknown:
            return AnimationProfile(bounceSpeed: 1.8, bounceAmount: 1.4, swaySpeed: 1.5, swayAmount: 1.2, armSpeed: 1.8, armAmount: 4)
        }
    }

    private var bodyShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.24))
            .frame(width: 86 + abs(bounce * 2.0), height: 16 - min(abs(bounce), 4))
            .offset(y: 51)
    }

    private var statusGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [eyeColor.opacity(0.26), eyeColor.opacity(0.0)],
                    center: .center,
                    startRadius: 12,
                    endRadius: 66
                )
            )
            .frame(width: 132, height: 132)
            .scaleEffect(1.0 + wave(speed: 2.4, amplitude: 0.05))
            .opacity(status == .unknown ? 0.42 : 0.9)
    }

    private var face: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.63, blue: 0.30),
                            Color(red: 0.96, green: 0.36, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 96, height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color(red: 0.18, green: 0.10, blue: 0.08), lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 22, height: 14)
                        .blur(radius: 2)
                        .offset(x: -25, y: -20)
                )

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.08, green: 0.11, blue: 0.15))
                .frame(width: 62, height: 37)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 18) {
                eye
                eye
            }
            .offset(y: -4)

            HStack(spacing: 34) {
                cheek
                cheek
            }
            .offset(y: 8)

            mouth
                .offset(y: 9)
        }
    }

    private var eye: some View {
        Capsule()
            .fill(eyeColor)
            .frame(width: status == .waiting || isExcited ? 13 : 10, height: max(2, 5 * blinkAmount))
            .shadow(color: eyeColor.opacity(0.55), radius: status == .unknown ? 0 : 4)
    }

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.67, blue: 0.58).opacity(0.72))
            .frame(width: 12, height: 6)
    }

    private var mouth: some View {
        Capsule()
            .fill(Color.white.opacity(status == .unknown ? 0.35 : 0.78))
            .frame(width: isExcited ? 22 : (status == .waiting ? 10 : 16), height: isExcited ? 4 : 3)
            .rotationEffect(.degrees(status == .waiting ? wave(speed: 5.4, amplitude: 8) : 0))
    }

    private var torso: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(red: 0.84, green: 0.26, blue: 0.16))
            .frame(width: 58, height: 38)
            .overlay(
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        statusDot(delay: 0.0)
                        statusDot(delay: 0.28)
                        statusDot(delay: 0.56)
                    }

                    Capsule()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 23, height: 4)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(red: 0.18, green: 0.10, blue: 0.08), lineWidth: 3)
            )
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(eyeColor)
                .frame(width: 11, height: 11)
                .shadow(color: eyeColor.opacity(0.6), radius: 5)
                .scaleEffect(1.0 + wave(speed: 3.0, amplitude: 0.12))

            Capsule()
                .fill(Color(red: 0.18, green: 0.10, blue: 0.08))
                .frame(width: 5, height: 16)
        }
        .rotationEffect(.degrees(wave(speed: 3.2, amplitude: 8)))
    }

    private func sideFin(x: CGFloat, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(red: 0.94, green: 0.43, blue: 0.22))
            .frame(width: 18, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(red: 0.18, green: 0.10, blue: 0.08), lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation + wave(speed: 2.6, amplitude: 3)))
            .offset(x: x, y: -4)
    }

    private func arm(x: CGFloat, side: CGFloat) -> some View {
        let baseRotation = side < 0 ? -20.0 : 20.0
        let waveRotation = wave(
            speed: animationProfile.armSpeed,
            amplitude: animationProfile.armAmount,
            phaseOffset: side > 0 ? 0.7 : 0
        )

        return Capsule()
            .fill(Color(red: 0.88, green: 0.31, blue: 0.18))
            .frame(width: 16, height: 42)
            .overlay(Capsule().stroke(Color(red: 0.18, green: 0.10, blue: 0.08), lineWidth: 3))
            .overlay(
                Circle()
                    .fill(Color(red: 1.0, green: 0.63, blue: 0.33))
                    .frame(width: 10, height: 10)
                    .offset(y: 13)
            )
            .rotationEffect(
                .degrees(baseRotation + waveRotation * Double(side)),
                anchor: UnitPoint(x: side < 0 ? 1.0 : 0.0, y: 0.12)
            )
            .offset(x: x, y: 48 + wave(speed: 4.2, amplitude: 1.5, phaseOffset: side > 0 ? 0.4 : 0))
    }

    private func leg(x: CGFloat, stepOffset: Double) -> some View {
        Capsule()
            .fill(Color(red: 0.78, green: 0.22, blue: 0.15))
            .frame(width: 18, height: 31)
            .overlay(Capsule().stroke(Color(red: 0.18, green: 0.10, blue: 0.08), lineWidth: 3))
            .rotationEffect(.degrees(wave(speed: animationProfile.bounceSpeed, amplitude: 6, phaseOffset: stepOffset)))
            .offset(x: x, y: 50 + wave(speed: animationProfile.bounceSpeed, amplitude: 2, phaseOffset: stepOffset))
    }

    private func statusDot(delay: Double) -> some View {
        Circle()
            .fill(eyeColor.opacity(0.84))
            .frame(width: 5, height: 5)
            .scaleEffect(0.78 + pulse(delay: delay) * 0.38)
            .opacity(0.55 + pulse(delay: delay) * 0.38)
    }

    private func sparkle(x: CGFloat, y: CGFloat, delay: Double) -> some View {
        let pulse = pulse(delay: delay)

        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.68))
                .frame(width: 3, height: 12)
            Capsule()
                .fill(Color.white.opacity(0.68))
                .frame(width: 12, height: 3)
        }
        .scaleEffect(0.65 + pulse * 0.36)
        .opacity(isExcited ? 0.42 + pulse * 0.42 : (status == .unknown ? 0.0 : 0.24 + pulse * 0.36))
        .rotationEffect(.degrees(wave(speed: 2.2, amplitude: 16, phaseOffset: delay)))
        .offset(x: x, y: y)
    }

    private var eyeColor: Color {
        switch status {
        case .busy:
            return Color(red: 0.45, green: 0.92, blue: 1.0)
        case .waiting:
            return Color(red: 1.0, green: 0.88, blue: 0.36)
        case .idle:
            return PetOverlayPalette.idleEyeGreen
        case .unknown:
            return Color.white.opacity(0.65)
        }
    }

    private func wave(speed: Double, amplitude: CGFloat, phaseOffset: Double = 0) -> CGFloat {
        CGFloat(sin(seconds * speed + phaseOffset)) * amplitude
    }

    private func pulse(delay: Double) -> CGFloat {
        let value = sin(seconds * 4.0 + delay)
        return CGFloat((value + 1.0) / 2.0)
    }
}

private struct AnimationProfile {
    let bounceSpeed: Double
    let bounceAmount: CGFloat
    let swaySpeed: Double
    let swayAmount: CGFloat
    let armSpeed: Double
    let armAmount: CGFloat
}

private func statusColor(_ status: ClaudeDisplayStatus) -> Color {
    switch status {
    case .busy:
        return Color(red: 0.35, green: 0.82, blue: 1.0)
    case .waiting:
        return Color(red: 1.0, green: 0.76, blue: 0.28)
    case .idle:
        return PetOverlayPalette.codexGreen
    case .unknown:
        return Color.white.opacity(0.52)
    }
}

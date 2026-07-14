import AppKit
import PetsCore
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

enum PetOverlayPalette {
    static let controlFill = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 20.0 / 255.0)
    static let sessionFill = Color(red: 24.0 / 255.0, green: 24.0 / 255.0, blue: 24.0 / 255.0)
    static let overflowFill = sessionFill
    static let codexGreen = Color(red: 107.0 / 255.0, green: 198.0 / 255.0, blue: 127.0 / 255.0)
    static let codexGreenText = Color(red: 0.035, green: 0.14, blue: 0.075)
    static let idleEyeGreen = Color(red: 0.52, green: 0.82, blue: 0.56)
}

func statusColor(_ status: HarnessSessionStatus) -> Color {
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

struct PetOverlayView: View {
    @ObservedObject var store: PetStore
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
                                visualContext: PetVisualContext(
                                    status: store.dominantStatus,
                                    hasActiveSessions: !store.visibleSessions.isEmpty,
                                    isHovered: isPetHovered,
                                    animationSettings: petInstance.animationSettings,
                                    reaction: store.currentReaction,
                                    animationPhaseOffset: PetAnimationPhaseOffset.normalized(
                                        for: petInstance.id.uuidString
                                    )
                                ),
                                pixelation: petInstance.pixelation
                            )
                                .id(petInstance.pixelation)
                                .frame(width: PetOverlayMetrics.spriteSize, height: PetOverlayMetrics.spriteSize)
                                .scaleEffect(PetOverlayMetrics.petScale)
                                .frame(
                                    width: PetOverlayMetrics.spriteSize * PetOverlayMetrics.petScale,
                                    height: PetOverlayMetrics.spriteSize * PetOverlayMetrics.petScale
                                )
                                .contentShape(Rectangle())
                                .animation(.spring(response: 0.18, dampingFraction: 0.52), value: isPetHovered)
                                .onHover { hovering in
                                    isPetHovered = petInstance.animationSettings.isHoverBounceEnabled && hovering
                                }
                                .contextMenu {
                                    ForEach(PetCatalog.builtInPetIDs.filter(store.isPetOwned), id: \.self) { petID in
                                        Button {
                                            store.selectPetInstance(petInstance.id)
                                            store.selectPet(petID)
                                        } label: {
                                            Label(
                                                PetCatalog.displayName(for: petID),
                                                systemImage: petInstance.petID == petID ? "checkmark" : "cloud"
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
    @ObservedObject var store: PetStore
    let contextLineCount: Int

    var body: some View {
        if let lastError = store.lastError {
            SessionMessageBubble(
                status: .unknown,
                title: "Session error",
                message: lastError
            )
        } else if store.sessions.isEmpty {
            SessionMessageBubble(
                status: .unknown,
                title: "Sessions",
                message: "No live Sessions"
            )
        } else if store.visibleSessions.isEmpty {
            SessionMessageBubble(
                status: .unknown,
                title: "Sessions",
                message: "All Sessions dismissed"
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
    let status: HarnessSessionStatus
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
    let status: HarnessSessionStatus

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
    let sessions: [HarnessSession]
    let visibleRowLimit: Int
    let contextLineCount: Int
    let onActivate: (HarnessSession) -> Void
    let onReply: (HarnessSession, String) -> Void
    let onDismiss: (HarnessSession) -> Void

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
    let status: HarnessSessionStatus
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
    let session: HarnessSession
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
                    SessionStatusIndicator(status: session.status)

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
        .background(Capsule().fill(statusColor(session.status)))
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
    let status: HarnessSessionStatus

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

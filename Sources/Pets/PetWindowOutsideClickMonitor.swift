import AppKit
import SwiftUI

struct PetWindowOutsideClickMonitor: NSViewRepresentable {
    let dismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeNSView(context: Context) -> NSView {
        let view = HitPassthroughView()
        context.coordinator.startMonitoring(view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.dismiss = dismiss
        context.coordinator.startMonitoring(view: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
    }

    @MainActor
    final class Coordinator {
        var dismiss: () -> Void
        private weak var view: NSView?
        private var eventMonitor: Any?

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func startMonitoring(view: NSView) {
            self.view = view
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                precondition(Thread.isMainThread)
                let eventBox = MainThreadEvent(event)
                let shouldSwallow = MainActor.assumeIsolated {
                    self?.handle(eventBox.value) ?? false
                }
                return shouldSwallow ? nil : event
            }
        }

        private func handle(_ event: NSEvent) -> Bool {
            guard let view, let monitoredWindow = view.window else { return false }

            if event.window !== monitoredWindow {
                dismiss()
                return true
            }

            let pointInMonitoredView = view.convert(event.locationInWindow, from: nil)
            guard !view.bounds.contains(pointInMonitoredView) else { return false }
            dismiss()
            return true
        }

        func stopMonitoring() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private struct MainThreadEvent: @unchecked Sendable {
        let value: NSEvent

        init(_ value: NSEvent) {
            self.value = value
        }
    }

    private final class HitPassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

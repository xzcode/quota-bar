import AppKit
import SwiftUI

/// Controls the borderless, draggable desktop card without taking focus.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let positionStore = WindowPositionStore()
    private var panel: NSPanel?

    func show() {
        if panel == nil { createPanel() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        panel?.level = enabled ? .floating : .normal
    }

    private func createPanel() {
        let content = QuotaWidgetView()
            .environmentObject(AppState.shared)
        let hostingView = NSHostingView(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 210),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = AppState.shared.alwaysOnTop ? .floating : .normal
        panel.delegate = self

        if let origin = positionStore.load() {
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }

        self.panel = panel
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel else { return }
        positionStore.save(panel.frame.origin)
    }
}

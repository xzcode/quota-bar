import AppKit
import SwiftUI

/// Controls the borderless, draggable desktop card without taking focus.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let positionStore = WindowPositionStore()
    private var panel: NSPanel?

    func show() {
        if panel == nil { createPanel() }
        panel?.level = AppState.shared.alwaysOnTop ? .statusBar : .normal
        panel?.orderFrontRegardless()
    }

    /// Explicitly raises the existing panel without creating another window.
    func bringToFront() {
        show()
    }

    /// Resizes the same panel while preserving its top edge and horizontal
    /// center, so expanding feels like the card grows downward in place.
    func setPresentationState(_ state: WidgetPresentationState, animated: Bool) {
        guard let panel else { return }

        let size = state.panelSize
        let currentFrame = panel.frame
        let targetFrame = NSRect(
            x: currentFrame.midX - size.width / 2,
            y: currentFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        let visibleOrigin = positionStore.visibleOrigin(for: targetFrame.origin, size: targetFrame.size)
        let reachableFrame = targetFrame.offsetBy(
            dx: visibleOrigin.x - targetFrame.origin.x,
            dy: visibleOrigin.y - targetFrame.origin.y
        )

        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate {
            panel.setFrame(reachableFrame, display: true, animate: true)
        } else {
            panel.setFrame(reachableFrame, display: true)
        }
        positionStore.save(reachableFrame.origin)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        panel?.level = enabled ? .statusBar : .normal
        if enabled, panel?.isVisible == true {
            panel?.orderFrontRegardless()
        }
    }

    private func createPanel() {
        let content = QuotaWidgetView()
            .environmentObject(AppState.shared)
        let hostingView = NSHostingView(rootView: content)
        let presentationState = AppState.shared.presentationState
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 210),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // The panel's native shadow follows its rectangular frame, unlike the rounded card.
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.level = AppState.shared.alwaysOnTop ? .statusBar : .normal
        panel.delegate = self

        // Keep the initial frame in sync with the restored presentation state
        // before applying the saved origin.
        let initialSize = presentationState.panelSize
        panel.setContentSize(initialSize)

        if let origin = positionStore.load() {
            let reachableOrigin = positionStore.visibleOrigin(for: origin, size: initialSize)
            panel.setFrameOrigin(reachableOrigin)
            positionStore.save(reachableOrigin)
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

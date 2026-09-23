import AppKit

/// Observes system wake events that do not necessarily activate the app.
enum AppLifecycleObserver {
    @MainActor
    static func observeWake(action: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                action()
            }
        }
    }

    static func remove(_ token: NSObjectProtocol) {
        NotificationCenter.default.removeObserver(token)
    }
}

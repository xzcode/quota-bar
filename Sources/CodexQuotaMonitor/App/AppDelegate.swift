import AppKit

/// Bridges AppKit lifecycle events into the shared application state.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory activation policy removes the Dock icon and Cmd+Tab entry.
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.applicationDidBecomeActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stop()
    }
}

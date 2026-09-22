import AppKit

/// Bridges AppKit lifecycle events into the shared application state.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var terminationWasRequested = false

    /// Gives the explicit Quit menu action permission to end the process.
    static func requestTermination() {
        terminationWasRequested = true
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory activation policy removes the Dock icon and Cmd+Tab entry.
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.start()
    }

    /// A menu-bar-only app must remain alive even while it has no normal windows.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Prevents SwiftUI/AppKit automatic termination of the menu-bar-only app.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Self.terminationWasRequested ? .terminateNow : .terminateCancel
    }

    /// Re-show the floating card when LaunchServices reopens an existing app.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppState.shared.start()
        }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.applicationDidBecomeActive()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stop()
    }
}

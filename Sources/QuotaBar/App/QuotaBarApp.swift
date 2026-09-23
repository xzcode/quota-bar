import SwiftUI

/// SwiftUI entry point for the menu-bar application.
@main
struct QuotaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // MenuBarExtra keeps the app out of the Dock while still providing a
        // native macOS menu-bar entry point.
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label(appState.menuBarTitle, systemImage: "gauge.with.dots.needle.33percent")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

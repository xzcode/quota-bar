import AppKit
import Foundation
import SwiftUI

/// Shared observable state used by the menu bar, settings, and floating panel.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let quotaViewModel: QuotaViewModel

    @Published private(set) var isPanelVisible = true
    @Published private(set) var presentationState: WidgetPresentationState
    @Published var alwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: SettingsKey.alwaysOnTop)
            floatingPanelController.setAlwaysOnTop(alwaysOnTop)
        }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin()
        }
    }
    @Published var showMenuBarPercentage: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarPercentage, forKey: SettingsKey.showMenuBarPercentage)
        }
    }
    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: SettingsKey.refreshInterval)
            restartScheduler()
        }
    }

    private let floatingPanelController: FloatingPanelController
    private let refreshScheduler = RefreshScheduler()
    private var wakeObserver: NSObjectProtocol?
    private var didStart = false

    private init() {
        alwaysOnTop = UserDefaults.standard.object(forKey: SettingsKey.alwaysOnTop) as? Bool ?? false
        presentationState = UserDefaults.standard.string(forKey: SettingsKey.widgetPresentationState)
            .flatMap(WidgetPresentationState.init(rawValue:)) ?? .collapsed
        launchAtLogin = UserDefaults.standard.object(forKey: SettingsKey.launchAtLogin) as? Bool ?? false
        showMenuBarPercentage = UserDefaults.standard.object(forKey: SettingsKey.showMenuBarPercentage) as? Bool ?? true
        refreshInterval = UserDefaults.standard.object(forKey: SettingsKey.refreshInterval) as? TimeInterval ?? 60

        let client = CodexAppServerClient(resolver: CodexExecutableResolver())
        quotaViewModel = QuotaViewModel(client: client)
        floatingPanelController = FloatingPanelController()
    }

    /// Starts the panel and the initial/periodic refresh loop once per process.
    func start() {
        guard !didStart else { return }
        didStart = true

        floatingPanelController.show()
        wakeObserver = AppLifecycleObserver.observeWake { [weak self] in
            self?.refreshNow()
        }
        restartScheduler()
    }

    /// Stops background work when the application is about to exit.
    func stop() {
        refreshScheduler.stop()
        if let wakeObserver {
            AppLifecycleObserver.remove(wakeObserver)
            self.wakeObserver = nil
        }
        Task {
            await quotaViewModel.stopClient()
        }
    }

    /// Refreshes after the app returns from the background or sleep.
    func applicationDidBecomeActive() {
        Task {
            await quotaViewModel.refresh(manual: false)
        }
    }

    /// Toggles the desktop card without changing the menu-bar process.
    func togglePanel() {
        if isPanelVisible {
            floatingPanelController.hide()
        } else {
            floatingPanelController.show()
        }
        isPanelVisible.toggle()
    }

    /// Expands or collapses the existing panel without creating another window.
    func togglePresentationState() {
        setPresentationState(presentationState == .collapsed ? .expanded : .collapsed)
    }

    /// Persists the presentation choice and keeps the panel's top edge stable.
    func setPresentationState(_ state: WidgetPresentationState) {
        guard presentationState != state else { return }
        presentationState = state
        UserDefaults.standard.set(state.rawValue, forKey: SettingsKey.widgetPresentationState)
        floatingPanelController.setPresentationState(state, animated: true)
    }

    /// Performs an immediate user-requested refresh.
    func refreshNow() {
        Task {
            await quotaViewModel.refresh(manual: true)
        }
    }

    var menuBarTitle: String {
        guard showMenuBarPercentage else { return "Codex" }
        return "C \(quotaViewModel.menuBarPercentageText)"
    }

    private func restartScheduler() {
        guard didStart else { return }
        refreshScheduler.start(
            interval: { [weak self] in self?.refreshInterval ?? 60 },
            refresh: { [weak self] in
                guard let self else { return false }
                return await self.quotaViewModel.refresh(manual: false)
            }
        )
    }

    private func updateLaunchAtLogin() {
        UserDefaults.standard.set(launchAtLogin, forKey: SettingsKey.launchAtLogin)

        do {
            if launchAtLogin {
                try LaunchAtLoginController.register()
            } else {
                try LaunchAtLoginController.unregister()
            }
        } catch {
            // A source checkout is not always a bundled app, so registration
            // can fail during development. Keep the preference visible and
            // report the actionable error in the settings UI on next launch.
            UserDefaults.standard.set(false, forKey: SettingsKey.launchAtLogin)
            launchAtLogin = false
            quotaViewModel.setTransientNotice(error.localizedDescription)
        }
    }
}

/// Centralized UserDefaults keys prevent accidental changes to persisted data.
enum SettingsKey {
    static let alwaysOnTop = "settings.alwaysOnTop"
    static let launchAtLogin = "settings.launchAtLogin"
    static let showMenuBarPercentage = "settings.showMenuBarPercentage"
    static let refreshInterval = "settings.refreshInterval"
    static let widgetPresentationState = "settings.widgetPresentationState"
    static let customCodexPath = "settings.customCodexPath"
    static let cachedSnapshot = "cache.quotaSnapshot"
}

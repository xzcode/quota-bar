import AppKit
import SwiftUI
import CodexQuotaCore

/// Menu-bar detail menu with the same live snapshot as the desktop card.
struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: QuotaViewModel

    init() {
        _viewModel = ObservedObject(wrappedValue: AppState.shared.quotaViewModel)
    }

    var body: some View {
        Text("Codex Quota")
            .font(.headline)

        if let bucket = viewModel.primaryBucket {
            ForEach(bucket.windows) { window in
                Text("\(QuotaFormatter.windowTitle(minutes: window.windowDurationMinutes))   \(window.remainingPercent)%")
            }
        } else {
            Text(viewModel.status.label)
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.secondary)
        }

        Text("上次更新：\(viewModel.lastUpdatedText)")
            .foregroundStyle(.secondary)
        Divider()
        Button("置顶显示桌面挂件") {
            appState.bringPanelToFront()
        }
        if appState.isPanelVisible {
            Button("隐藏桌面挂件") {
                appState.togglePanel()
            }
        }
        Button("立即刷新") {
            appState.refreshNow()
        }
        SettingsLink { Text("设置") }
        Divider()
        Button("退出") {
            AppDelegate.requestTermination()
        }
    }
}

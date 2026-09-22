import AppKit
import SwiftUI
import CodexQuotaCore

/// Compact translucent desktop card shown inside the borderless NSPanel.
struct QuotaWidgetView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: QuotaViewModel

    init() {
        _viewModel = ObservedObject(wrappedValue: AppState.shared.quotaViewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let bucket = viewModel.primaryBucket {
                if let name = bucket.name ?? bucket.normalModelSlug {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(bucket.windows) { window in
                    QuotaRowView(window: window)
                }
            } else {
                emptyState
            }

            footer
        }
        .padding(18)
        .frame(width: 330)
        .frame(minHeight: 190)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Codex")
                .font(.title3.weight(.bold))
            Spacer()
            Button {
                appState.refreshNow()
            } label: {
                Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("立即刷新")
            .disabled(viewModel.isRefreshing)

            Menu {
                Button("显示/隐藏桌面挂件") { appState.togglePanel() }
                SettingsLink { Text("设置") }
                Divider()
                Button("退出") { AppDelegate.requestTermination() }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.status.label)
                .font(.headline)
            Text(viewModel.errorMessage ?? "当前账户未返回额度窗口")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.status == .notAuthenticated {
                Text("请先在 Terminal 执行 codex login")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("复制命令") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("codex login", forType: .string)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.status.color)
                    .frame(width: 7, height: 7)
                Text(viewModel.status.label)
                Spacer()
                Text(viewModel.lastUpdatedText)
            }
            if let staleMessage = viewModel.staleMessage {
                Text(staleMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

import AppKit
import SwiftUI
import CodexQuotaCore

/// Compact/expanded quota widget shown inside the single borderless NSPanel.
struct QuotaWidgetView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: QuotaViewModel

    init() {
        _viewModel = ObservedObject(wrappedValue: AppState.shared.quotaViewModel)
    }

    var body: some View {
        Group {
            if appState.presentationState == .collapsed {
                collapsedContent
            } else {
                expandedContent
            }
        }
        .frame(
            width: appState.presentationState.panelSize.width,
            height: appState.presentationState.panelSize.height
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: appState.presentationState)
    }

    /// Phase 1 keeps the compact state intentionally quiet; particles and the
    /// animated gradient belong to the later visual-polish phase.
    private var collapsedContent: some View {
        Text(viewModel.menuBarPercentageText)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
            .contentShape(Capsule())
            .onTapGesture {
                appState.setPresentationState(.expanded)
            }
            .help("展开额度详情")
            .preferredColorScheme(.dark)
    }

    private var expandedContent: some View {
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
        .frame(width: 330, height: 210)
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
                appState.setPresentationState(.collapsed)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .help("收起额度详情")

            Button {
                appState.refreshNow()
            } label: {
                Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("立即刷新")
            .disabled(viewModel.isRefreshing)

            Menu {
                Button("收起") { appState.setPresentationState(.collapsed) }
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

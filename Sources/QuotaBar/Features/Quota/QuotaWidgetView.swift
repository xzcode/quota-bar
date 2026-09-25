import AppKit
import SwiftUI
import CodexQuotaCore

/// Compact/expanded quota widget shown inside the single borderless NSPanel.
struct QuotaWidgetView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var viewModel: QuotaViewModel
    @State private var isHovered = false

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
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.88),
            value: appState.presentationState
        )
    }

    private var collapsedContent: some View {
        CompactQuotaBar(
            remaining: viewModel.collapsedDisplayRemainingPercent,
            quotaSummary: viewModel.collapsedQuotaSummary,
            activityLevel: viewModel.compactActivityLevel,
            isStale: viewModel.isStale,
            isDemoMode: viewModel.isEnergyDemoMode,
            reduceMotion: reduceMotion,
            isHovered: isHovered
        )
        .brightness(isHovered ? 0.04 : 0)
        .onHover { isHovered = $0 }
        .contentShape(Capsule())
        .onTapGesture {
            appState.setPresentationState(.expanded)
        }
        .help(viewModel.compactTooltipText)
        .contextMenu {
            Button("展开") { appState.setPresentationState(.expanded) }
            Button("立即刷新") { appState.refreshNow() }
            Button(appState.alwaysOnTop ? "取消始终置顶" : "始终置顶") {
                appState.alwaysOnTop.toggle()
            }
            SettingsLink { Text("设置") }
            Button("复制诊断信息") { copyDiagnostics() }
            energyEffectsMenu
            Divider()
            Button("退出") { AppDelegate.requestTermination() }
        }
        .preferredColorScheme(.dark)
    }

    /// Keeps visual-effect controls available in both release and debug app bundles.
    private var energyEffectsMenu: some View {
        Menu {
            Section("模拟粒子活动") {
                energyLevelButton("静止", level: .calm)
                energyLevelButton("慢速", level: .slow)
                energyLevelButton("中速", level: .medium)
                energyLevelButton("快速", level: .fast)
                energyLevelButton("飞快", level: .veryFast)
            }
            Section {
                Button {
                    viewModel.setEnergyDemoLevel(nil)
                } label: {
                    if viewModel.energyDemoLevel == nil {
                        Label("跟随真实 Token 活动", systemImage: "checkmark")
                    } else {
                        Text("跟随真实 Token 活动")
                    }
                }
            }
        } label: {
            Label("效果调试", systemImage: "sparkles")
        }
        .help("临时覆盖胶囊的粒子活动档位，不影响额度或 Token 统计")
    }

    /// Marks the currently forced activity tier while leaving other tiers directly selectable.
    private func energyLevelButton(_ title: String, level: TokenActivityLevel) -> some View {
        Button {
            viewModel.setEnergyDemoLevel(level)
        } label: {
            if viewModel.energyDemoLevel == level {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let bucket = viewModel.primaryBucket {
                if let name = bucket.name ?? bucket.normalModelSlug {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
                ForEach(bucket.windows) { window in
                    QuotaRowView(window: window)
                }
            } else {
                emptyState
            }

            LocalTokenUsageIndicator(
                snapshot: viewModel.localTokenUsage,
                tooltipText: viewModel.localTokenUsageTooltipText
            )

            footer
        }
        .padding(18)
        .frame(width: 330, height: 210)
        .background(ExpandedCardBackground())
        .shadow(color: .black.opacity(0.27), radius: 20, y: 10)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Codex")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white.opacity(0.98))
            Spacer()
            Button {
                appState.setPresentationState(.collapsed)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help("收起额度详情")

            Button {
                appState.refreshNow()
            } label: {
                Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .rotationEffect(.degrees(viewModel.isRefreshing && !reduceMotion ? 360 : 0))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help("立即刷新")
            .disabled(viewModel.isRefreshing)
            .animation(
                viewModel.isRefreshing && !reduceMotion
                    ? .linear(duration: 0.9).repeatForever(autoreverses: false)
                    : .easeOut(duration: 0.12),
                value: viewModel.isRefreshing
            )

            Menu {
                Button("收起") { appState.setPresentationState(.collapsed) }
                Button("立即刷新") { appState.refreshNow() }
                Button(appState.alwaysOnTop ? "取消始终置顶" : "始终置顶") {
                    appState.alwaysOnTop.toggle()
                }
                SettingsLink { Text("设置") }
                Button("复制诊断信息") { copyDiagnostics() }
                energyEffectsMenu
                Divider()
                Button("退出") { AppDelegate.requestTermination() }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.snapshot == nil ? "额度暂时不可用" : viewModel.status.label)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.97))
            Text(viewModel.errorMessage ?? "当前账户未返回额度窗口")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
            if viewModel.status == .notAuthenticated {
                Text("请先在 Terminal 执行 codex login")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
                Button("复制命令") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("codex login", forType: .string)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.status.color)
                    .frame(width: 7, height: 7)
                Text(viewModel.footerStatusText)
                    .foregroundStyle(.white.opacity(0.76))
                Spacer()
                Text(viewModel.lastUpdatedText)
                    .foregroundStyle(.white.opacity(0.50))
            }
            if let staleMessage = viewModel.staleMessage {
                Text(staleMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.95))
                    .lineLimit(2)
            }
        }
        .font(.caption)
    }

    /// Copies only the sanitized, user-facing diagnostic summary.
    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.diagnosticText, forType: .string)
    }

}

/// Builds a fixed dark glass surface so desktop appearance never washes out the expanded card.
private struct ExpandedCardBackground: View {
    private let cornerRadius: CGFloat = 20

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape.fill(
                LinearGradient(
                    colors: [rgb(0x15, 0x1A, 0x24), rgb(0x12, 0x15, 0x1B), rgb(0x18, 0x14, 0x21)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Low-opacity radial glows add depth without tinting the dark base purple or blue.
            GeometryReader { geometry in
                ZStack {
                    RadialGradient(
                        colors: [rgb(0x45, 0x68, 0xC8).opacity(0.08), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.9
                    )
                    RadialGradient(
                        colors: [rgb(0x76, 0x4A, 0xA8).opacity(0.06), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.9
                    )
                }
                .blur(radius: 26)
            }
            .clipShape(shape)

            // A restrained top-edge highlight preserves the glass feel without a bright double rim.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.white.opacity(0.045), .white.opacity(0.008), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 1)
            .clipShape(shape)

            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.11), rgb(0x91, 0x9D, 0xC5).opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )

            shape.inset(by: 1).stroke(.white.opacity(0.035), lineWidth: 1)
        }
    }

    /// Converts byte-style RGB values to normalized SwiftUI color components.
    private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
    }
}

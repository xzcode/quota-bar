import AppKit
import SwiftUI

/// Minimal settings screen for the V1 behavior switches.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("窗口") {
                Toggle("始终置顶", isOn: $appState.alwaysOnTop)
                Toggle("显示菜单栏百分比", isOn: $appState.showMenuBarPercentage)
            }

            Section("刷新") {
                Picker("刷新间隔", selection: $appState.refreshInterval) {
                    Text("30 秒").tag(TimeInterval(30))
                    Text("60 秒").tag(TimeInterval(60))
                    Text("2 分钟").tag(TimeInterval(120))
                    Text("5 分钟").tag(TimeInterval(300))
                }
            }

            Section("启动") {
                Toggle("开机启动", isOn: $appState.launchAtLogin)
                Text("开机启动需要应用已打包为 .app；从源码运行时系统可能拒绝注册。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Codex CLI") {
                HStack {
                    Text(currentPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("选择路径") { chooseCodexPath() }
                }
                Button("重新检测") {
                    appState.refreshNow()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    private var currentPath: String {
        UserDefaults.standard.string(forKey: SettingsKey.customCodexPath) ?? "自动发现 Codex CLI"
    }

    private func chooseCodexPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.path, forKey: SettingsKey.customCodexPath)
            appState.refreshNow()
        }
    }
}

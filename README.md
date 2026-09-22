# Codex Quota Monitor

一个使用 Swift 6、SwiftUI 和 AppKit 实现的 macOS 14+ Codex 额度桌面挂件与菜单栏应用。

## 系统要求

- macOS 14 Sonoma 或更高
- 已安装并登录 Codex CLI
- Swift 6 / Xcode Command Line Tools（源码构建）

应用只通过本机 `codex app-server --listen stdio://` 获取额度，不读取 `~/.codex/auth.json`，也不调用私有 HTTP usage endpoint。

## 构建与运行

开发调试：

```bash
swift build
swift run CodexQuotaMonitor
```

协议诊断（只输出 rate-limit 字段结构，不输出认证信息）：

```bash
./Scripts/diagnose-app-server.py
```

运行纯协议测试：

```bash
swift run CodexQuotaMonitorTests
```

生成可双击运行的 `.app`：

```bash
./Scripts/package-app.sh
open dist/CodexQuotaMonitor.app
```

打包脚本会将 SwiftPM release binary 放入应用包，并设置 `LSUIElement`，因此应用默认不显示 Dock 图标。

## Codex CLI 要求

程序按以下顺序查找 `codex`：

1. 设置中选择的自定义路径
2. `/opt/homebrew/bin/codex`
3. `/usr/local/bin/codex`
4. `~/.local/bin/codex`
5. `/bin/zsh -lc 'command -v codex'`

找到后会执行 `codex --version` 验证路径。若未找到，挂件会显示“未检测到 Codex CLI”，不会崩溃。

## 权限与安全

- 不需要用户手动输入 Token。
- 不解析或持久化认证文件。
- 本地缓存只保存额度快照和时间戳。
- app-server 的 stderr 被持续消费但不写入日志，避免意外记录凭据。
- 开机启动使用系统 `SMAppService`，从源码直接运行时可能因没有 `.app` bundle 而无法注册。

## 常见错误

### Codex 尚未登录

在 Terminal 执行：

```bash
codex login
```

然后在菜单栏选择“立即刷新”。

### 显示服务异常或数据可能已过期

应用会保留最近一次成功快照，并按 5 秒、15 秒、45 秒、最多 60 秒的节奏恢复 app-server。也可以点击“立即刷新”立刻重试。

### 自定义 CLI 路径

打开“设置”，在“Codex CLI”区域选择可执行文件，再点击“重新检测”。

## 开发调试

```bash
swift build
swift run CodexQuotaMonitor
```

应用只记录已清理的生命周期信息，例如 app-server 启动、握手成功、刷新成功或失败；不会打印 access token、认证文件内容或完整账户凭据。

## Compatibility Notes

V1 优先解析当前规格中的 `result.rateLimitsByLimitId`，不存在、为空或全部 bucket 无法解析时回退到 `result.rateLimits`，并兼容直接返回 rate-limit object 的变体。未知 JSON 字段会被忽略；单个无法解析的 bucket 不会影响其他 bucket。

本机 `codex-cli 0.152.1` 对 `account/rateLimits/read` 的 object 参数返回 `-32600`（`expected unit`），因此客户端先尝试 `excludeResetCreditDetails`，遇到该 schema 错误时自动回退到无参数请求。诊断脚本会在输出中标记实际使用的 `requestMode`。

如果本机 Codex app-server 的字段或协议发生变化，应优先以本机官方 schema 为准，并在 `RateLimitParser` 中增加兼容映射，而不是绕过 app-server 读取认证文件或私有 HTTP 接口。

## 项目结构

```text
Sources/CodexQuotaMonitor/
├── App/          应用入口、生命周期和共享状态
├── Codex/        CLI 发现、JSON-RPC transport、额度解析
├── Features/     额度卡片、菜单栏、设置
├── Services/     刷新退避、睡眠唤醒、开机启动
└── Window/       NSPanel 与窗口位置持久化
```

核心解析、格式化和 JSON-RPC response 兼容性由 `CodexQuotaMonitorTests` runner 覆盖。当前机器仅安装 Command Line Tools，没有 XCTest/Swift Testing，因此使用无第三方依赖的 SwiftPM executable runner，并通过 `swift run CodexQuotaMonitorTests` 执行。

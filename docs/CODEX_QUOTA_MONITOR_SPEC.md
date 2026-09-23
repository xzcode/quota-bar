# QuotaBar — macOS 桌面额度挂件开发规格

> 版本：V1.0 MVP  
> 平台：macOS 14+  
> 目标：开发一个常驻 macOS 的轻量桌面挂件，用于查看 Codex 当前额度窗口、剩余额度百分比、重置时间与状态。

---

## 1. 项目目标

开发一个 **原生 macOS 桌面挂件 + 菜单栏应用**，用户无需打开 Codex App/CLI，即可随时看到当前 Codex 配额状态。

核心体验：

- 桌面上常驻一个小型、无边框、可拖动的额度卡片。
- 菜单栏始终显示当前最紧张的额度剩余百分比。
- 自动读取当前本机 Codex 登录态，不要求用户再次输入 Token。
- 自动刷新额度数据。
- 清晰展示所有实际返回的限额窗口，而不是假设一定存在“5 小时 + 周额度”。
- 额度较低时给予视觉提醒，后续可扩展系统通知。

V1 只做 **额度监控**，不做 Codex 对话、任务管理、模型切换或额度重置操作。

---

## 2. 技术路线

### 2.1 技术栈

必须使用：

- **Swift 6**
- **SwiftUI**：界面
- **AppKit**：无边框悬浮窗口 / NSPanel / 窗口层级控制
- **Foundation.Process**：启动 `codex app-server`
- **JSON-RPC 2.0 over stdio**：与 Codex app-server 通信
- **Swift Concurrency（async/await、Actor）**：进程通信与状态管理
- **UserDefaults / @AppStorage**：本地设置
- **ServiceManagement / SMAppService**：后续支持登录启动
- **Swift Package Manager**：依赖与构建

V1 **禁止引入第三方依赖**，除非系统能力明显无法满足。

### 2.2 最低系统版本

- macOS 14 Sonoma 或更高
- Apple Silicon 优先，但代码不得依赖 arm64 专有行为

### 2.3 为什么不用 WidgetKit

本项目不要实现成 WidgetKit Widget。

原因：

- WidgetKit 刷新频率受 macOS 控制，不适合实时额度监控。
- 需要持续与本地 Codex app-server 通信。
- 需要更灵活的自动刷新、错误恢复、拖动和置顶能力。

因此使用普通原生 macOS App，并模拟桌面 Widget 的视觉与交互。

---

## 3. Codex 额度数据来源

### 3.1 必须使用 Codex app-server

V1 **不得直接解析 `~/.codex/auth.json`，也不得直接调用私有 HTTP usage endpoint**。

统一通过本机安装的 Codex CLI 启动：

```bash
codex app-server --listen stdio://
```

应用通过 stdin/stdout 与该进程进行 JSON-RPC 2.0 通信。

这样做的目的：

- 不直接接触或持久化 Codex access token。
- 尽可能跟随官方 Codex 协议变化。
- 登录状态、账户选择和认证由 Codex 自己处理。

### 3.2 初始化握手

启动 app-server 后发送：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "clientInfo": {
      "name": "codex-quota-monitor",
      "title": "Codex Quota Monitor",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true
    }
  }
}
```

等待 `id = 1` 的成功响应后，再发送：

```json
{
  "jsonrpc": "2.0",
  "method": "initialized",
  "params": {}
}
```

初始化未完成前，禁止发送额度请求。

### 3.3 获取额度

调用：

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "account/rateLimits/read"
}
```

V1 优先使用响应中的：

```text
result.rateLimitsByLimitId
```

若不存在，则回退：

```text
result.rateLimits
```

核心字段：

```text
RateLimitSnapshot
  limitId
  limitName
  normalModelSlug
  primary
  secondary
  credits
  individualLimit

RateLimitWindow
  usedPercent
  windowDurationMins
  resetsAt
```

显示时计算：

```text
remainingPercent = max(0, 100 - usedPercent)
```

### 3.4 窗口不能硬编码

禁止假定所有账户都一定返回：

- 5 小时窗口
- 周窗口

应用必须根据 `windowDurationMins` 动态展示实际存在的窗口。

推荐显示规则：

```text
300 min     -> 5 小时
1440 min    -> 24 小时
10080 min   -> 周额度
其他         -> 自动格式化，如 2 小时 / 3 天 / 14 天
```

如果只有 primary，没有 secondary，只显示一个额度项。

如果 primary / secondary 都为空，则显示“当前账户未返回额度窗口”。

### 3.5 多额度 Bucket

如果存在：

```text
rateLimitsByLimitId
```

优先寻找 `limitId == "codex"` 作为默认主额度。

其他 bucket 可以在“详情”面板中列出，但 V1 主卡片不要一次展示过多内容。

不要根据模型名称自行猜测某个模型属于哪个 bucket。

只有后端明确返回 `normalModelSlug` / `limitName` 等映射信息时才显示模型关联。

### 3.6 实时更新策略

V1：

- App 启动后立即请求一次。
- 每 **60 秒**调用一次 `account/rateLimits/read`。
- 用户点击刷新按钮时立即刷新。
- App 从后台重新激活时刷新一次。
- 系统从睡眠唤醒后刷新一次。

如果收到 app-server 的额度更新 notification，可以提前刷新 UI，但不能完全依赖 notification。

---

## 4. Codex CLI 路径发现

macOS GUI App 的 PATH 与 Terminal 不一定相同，因此不能只执行：

```text
Process.executableURL = URL(fileURLWithPath: "codex")
```

实现 `CodexExecutableResolver`。

查找顺序：

1. 用户设置中的自定义 Codex 路径
2. `/opt/homebrew/bin/codex`
3. `/usr/local/bin/codex`
4. `~/.local/bin/codex`
5. `/bin/zsh -lc 'command -v codex'`

找到后执行一次：

```bash
codex --version
```

确认返回成功。

如果找不到，UI 显示：

```text
未检测到 Codex CLI
[重新检测] [选择路径]
```

不要直接崩溃。

---

## 5. 应用 UI

### 5.1 默认桌面挂件

尺寸建议：

```text
宽：300~340 pt
高：180~230 pt
圆角：18~22 pt
```

风格：

- macOS 原生感
- 深色半透明材质
- `.ultraThinMaterial` / `.thinMaterial`
- 少量阴影
- 不做复杂炫光
- 信息密度优先

参考布局：

```text
┌──────────────────────────────┐
│ Codex                         │
│                         ↻  •••│
│                              │
│ 5 小时额度                    │
│ ███████████████░░░  72% 剩余 │
│ 1 小时 43 分后重置            │
│                              │
│ 周额度                        │
│ ████████░░░░░░░░░  41% 剩余 │
│ 3 天 18 小时后重置            │
│                              │
│ ● 正常              20:52 更新│
└──────────────────────────────┘
```

### 5.2 进度条语义

进度条展示 **剩余额度**，而不是已使用额度。

颜色规则：

```text
remaining > 50%       正常色
25% < remaining <=50% 蓝/黄色轻提醒
10% < remaining <=25% 橙色
remaining <=10%       红色
```

不要仅依赖颜色表达状态，必须同时显示数字。

### 5.3 重置时间

每条额度同时显示：

```text
1 小时 43 分后重置
```

鼠标 Hover 或详情中显示绝对时间：

```text
2026-09-23 02:31
```

`resetsAt` 按 Unix 秒时间戳处理，并转换成本机时区。

如果 `resetsAt == null`：

```text
重置时间未知
```

### 5.4 状态栏

底部状态可显示：

```text
● 正常
● 额度偏低
● 即将耗尽
● Codex 未登录
● Codex 服务异常
```

右侧：

```text
刚刚更新
1 分钟前更新
```

### 5.5 菜单栏

使用 `MenuBarExtra`。

菜单栏显示当前最紧张额度：

```text
C 41%
```

算法：

```text
min(all visible remainingPercent)
```

点击菜单栏展开：

```text
QuotaBar

5 小时   72%
周额度   41%

上次更新：20:52
────────────
显示/隐藏桌面挂件
立即刷新
设置
退出
```

### 5.6 桌面窗口行为

使用 `NSPanel` 或自定义 `NSWindow`。

要求：

- 无标题栏
- 背景透明
- 可鼠标拖动
- 位置持久化
- 不出现在 Dock
- 不出现在 Cmd+Tab 应用切换器（优先实现为 accessory app）
- 默认不抢焦点
- 支持显示 / 隐藏

设置项：

```text
□ 始终置顶
□ 开机启动
□ 显示菜单栏百分比
刷新间隔：30 秒 / 60 秒 / 2 分钟 / 5 分钟
```

默认：

```text
始终置顶：开启（显示在普通应用窗口和全屏空间前面）
开机启动：关闭
菜单栏百分比：开启
刷新间隔：60 秒
```

菜单栏菜单提供“置顶显示桌面挂件”入口，用于重新显示并召回挂件。macOS 的系统级窗口（例如屏幕保护程序界面或部分安全提示）仍可能显示在挂件前面。

---

## 6. 工程结构

建议目录：

```text
QuotaBar/
├── App/
│   ├── QuotaBarApp.swift
│   ├── AppDelegate.swift
│   └── AppState.swift
│
├── Codex/
│   ├── CodexExecutableResolver.swift
│   ├── CodexAppServerClient.swift
│   ├── JSONRPCTransport.swift
│   ├── JSONRPCMessage.swift
│   └── RateLimitModels.swift
│
├── Features/
│   ├── Quota/
│   │   ├── QuotaViewModel.swift
│   │   ├── QuotaWidgetView.swift
│   │   ├── QuotaRowView.swift
│   │   └── QuotaFormatter.swift
│   │
│   ├── MenuBar/
│   │   └── MenuBarView.swift
│   │
│   └── Settings/
│       └── SettingsView.swift
│
├── Window/
│   ├── FloatingPanelController.swift
│   └── WindowPositionStore.swift
│
├── Services/
│   ├── RefreshScheduler.swift
│   └── AppLifecycleObserver.swift
│
└── Tests/
    ├── RateLimitParsingTests.swift
    ├── QuotaFormatterTests.swift
    └── JSONRPCTransportTests.swift
```

保持模块简单，不要为了“架构完整”过度设计。

---

## 7. 核心数据模型

应用内部统一模型建议：

```swift
struct QuotaBucket: Identifiable, Equatable {
    let id: String
    let name: String?
    let normalModelSlug: String?
    let windows: [QuotaWindow]
}

struct QuotaWindow: Identifiable, Equatable {
    let id: String
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    var remainingPercent: Int {
        max(0, 100 - usedPercent)
    }
}
```

UI 不直接绑定 JSON-RPC DTO。

必须设置 DTO -> Domain Model 的映射层。

---

## 8. JSON-RPC Transport 要求

`CodexAppServerClient` 必须负责 app-server 生命周期。

状态机：

```text
stopped
starting
initializing
ready
failed(error)
```

Transport 要求：

- stdin 一行一个 JSON message。
- stdout 持续逐行读取。
- stderr 单独消费，避免子进程 pipe 阻塞。
- 根据 `id` 匹配 request / response。
- notification 单独分发。
- request 设置超时，建议 10 秒。
- EOF / 子进程退出时，将状态置为 failed。
- 下一次刷新允许自动重启 app-server。

不得阻塞主线程。

不得在日志中打印：

- access token
- auth.json 内容
- 完整账户凭据

V1 日志只记录：

```text
app-server started
initialize succeeded
rate limit refresh succeeded
rate limit refresh failed: <sanitized error>
app-server exited: <exit code>
```

---

## 9. App Server 故障恢复

如果发生：

```text
codex app-server process exited
broken pipe
request timeout
invalid JSON response
```

执行：

1. 标记连接不可用。
2. 保留上一次成功额度，不立刻清空 UI。
3. UI 显示“数据可能已过期”。
4. 下一次刷新重新启动 app-server。
5. 连续失败不要高速重试。

重试建议：

```text
立即失败后：5 秒
再次失败：15 秒
再次失败：30 秒
之后最多每 60 秒一次
```

用户手动点击刷新时允许立即重试。

---

## 10. 登录状态与异常提示

至少处理：

### A. 未安装 Codex

```text
未检测到 Codex CLI
```

### B. Codex 未登录

如果 `account/rateLimits/read` 返回认证错误：

```text
Codex 尚未登录
请先在 Terminal 执行 codex login
```

提供按钮：

```text
复制命令
```

V1 不在 App 内实现登录页面。

### C. 网络不可用

```text
暂时无法获取额度
显示的是 20:52 的缓存数据
```

### D. API 字段变化

解析策略必须尽可能宽容：

- 未知字段忽略。
- optional 字段允许缺失。
- 单个 bucket 无法解析时不要导致整个 App 崩溃。

---

## 11. 本地缓存

每次成功刷新后缓存最近一次 Domain Snapshot。

保存：

```text
quota snapshot
capturedAt
```

不要保存认证信息。

App 冷启动时：

1. 先展示最近缓存。
2. 标记“正在刷新”。
3. 获取到新数据后替换。

缓存超过 24 小时仍可显示，但必须明确标记“数据已过期”。

---

## 12. V1 不做的功能

以下功能禁止在 V1 擅自加入：

- 直接调用 ChatGPT 私有 HTTP API
- 解析或保存 auth.json 中的 Token
- 自动切换 Codex 模型
- 自动启动 Codex 编程任务
- 消耗 / Redeem reset credits
- Luna Reserve 自动切换
- 根据历史使用量自动决策模型
- 云同步
- 登录系统
- 复杂趋势图
- Token 成本估算

保持第一版小而稳定。

---

## 13. V1.1 可扩展功能

V1 验收通过后可增加：

### 使用历史

每次额度刷新保存：

```text
timestamp
limitId
windowDuration
usedPercent
```

由本地历史推算：

```text
最近 1 小时消耗速度
最近 24 小时消耗速度
预计到重置前是否会耗尽
```

注意：这是本地估算，不要描述成官方预测。

### 系统通知

阈值：

```text
25%
10%
5%
```

同一个额度窗口同一个阈值只通知一次，重置后清空通知状态。

### 多 Bucket 详情

支持展示：

```text
codex
base_model_inference
其他后端返回 bucket
```

但仍禁止自行猜模型映射。

---

## 14. 测试要求

至少实现以下 Unit Tests。

### RateLimitParsingTests

覆盖：

1. primary + secondary 都存在
2. 只有 primary
3. 只有 secondary
4. `rateLimitsByLimitId` 存在
5. `rateLimitsByLimitId` 缺失，fallback 到 `rateLimits`
6. `resetsAt == null`
7. `windowDurationMins == null`
8. unknown fields
9. usedPercent = 0
10. usedPercent = 100

### QuotaFormatterTests

覆盖：

```text
300 -> 5 小时
10080 -> 周额度
60 -> 1 小时
1440 -> 24 小时
4320 -> 3 天
```

以及倒计时：

```text
45 分钟
1 小时 20 分
2 天 3 小时
已重置 / 时间已到
```

### JSONRPCTransportTests

使用 fake Process / fake stream 测试：

- request id 匹配
- timeout
- notification
- malformed JSON
- EOF
- process restart

---

## 15. 验收标准

V1 必须满足全部条件才算完成。

### 启动

- [ ] App 在 macOS 14+ 可以正常启动。
- [ ] 不显示普通 Dock 图标。
- [ ] 菜单栏出现 QuotaBar。
- [ ] 桌面额度卡片正常显示。

### Codex 集成

- [ ] 可以自动找到本机 codex CLI。
- [ ] 能启动 `codex app-server`。
- [ ] initialize handshake 正常。
- [ ] `account/rateLimits/read` 正常返回并解析。
- [ ] App 不直接读取 auth token。

### UI

- [ ] 显示实际存在的额度窗口。
- [ ] 正确显示剩余百分比。
- [ ] 正确显示重置倒计时。
- [ ] 窗口可拖动。
- [ ] 重启后恢复窗口位置。
- [ ] 菜单栏显示最低 remainingPercent。

### 刷新

- [ ] 默认每 60 秒刷新。
- [ ] 可以手动刷新。
- [ ] 睡眠恢复后自动刷新。
- [ ] app-server 崩溃后能够恢复。

### 异常

- [ ] Codex 未安装时不崩溃。
- [ ] Codex 未登录时有明确提示。
- [ ] 网络失败时保留最近缓存。
- [ ] 返回字段缺失时不崩溃。

### 安全

- [ ] 日志不输出 Token。
- [ ] 本地缓存不保存认证凭据。
- [ ] 不直接调用私有 usage HTTP API。

---

## 16. Codex 执行要求

请严格按照本文档实现，不要主动扩大范围。

开发顺序：

```text
Phase 1
CodexExecutableResolver
        ↓
启动 codex app-server
        ↓
JSON-RPC initialize
        ↓
account/rateLimits/read
        ↓
命令行打印解析结果

Phase 2
Domain Model
        ↓
QuotaViewModel
        ↓
SwiftUI 静态额度卡片
        ↓
接真实数据

Phase 3
NSPanel 桌面挂件
        ↓
MenuBarExtra
        ↓
窗口位置持久化

Phase 4
60 秒自动刷新
        ↓
错误恢复
        ↓
缓存
        ↓
设置页

Phase 5
Unit Tests
        ↓
README
        ↓
完整手动验收
```

每完成一个 Phase 都应保证可以编译运行，再继续下一阶段。

如果当前安装的 Codex app-server schema 与本文档存在差异，应：

1. 优先遵循当前本机 Codex 官方 schema。
2. 保持客户端向后兼容。
3. 不通过读取 auth.json 或调用私有 HTTP API 绕过 app-server。
4. 将差异记录在 README 的 `Compatibility Notes` 中。

---

## 17. 最终交付物

Codex 最终应交付：

```text
QuotaBar.app
源码
README.md
基本单元测试
```

README 至少包含：

```text
系统要求
安装方式
如何运行
Codex CLI 要求
权限说明
常见错误
开发调试方法
app-server compatibility notes
```

项目应做到：

> 用户安装后，只要本机 Codex 已经登录，就能直接看到额度，无需任何额外配置。

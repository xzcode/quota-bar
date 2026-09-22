# quota-bar 下一步开发任务

仓库：`xzcode/quota-bar`  
审查基线：`master` / commit `6a917abee127fc61e201d6dca59f61abf397e0c8`

## 1. 当前结论

当前项目总体技术路线正确：

- Swift 6
- SwiftUI
- AppKit / `NSPanel`
- Swift Package Manager
- 无第三方依赖
- 通过本机 `codex app-server --listen stdio://` 获取额度
- 使用 JSON-RPC 与 app-server 通信
- 不直接读取 `~/.codex/auth.json`
- 不自己持有或记录 access token

当前不需要改成 Tauri，也不需要建立 Xcode Project。

开发阶段继续使用：

```bash
swift build
swift run CodexQuotaMonitor
```

即可。只需要 macOS Command Line Tools / Swift toolchain；Xcode IDE 不是当前项目的必需品。

---

# 2. 当前首要问题

现在桌面挂件已经能启动，但额度没有正确显示。

不要继续优化 UI。

下一阶段只解决：

> **在用户当前安装的 Codex CLI 上，稳定拿到并正确解析真实的 rate limit 数据。**

当前代码中的主要链路：

```text
CodexExecutableResolver
        ↓
codex app-server --listen stdio://
        ↓
initialize
        ↓
initialized
        ↓
account/rateLimits/read
        ↓
RateLimitParser
        ↓
QuotaViewModel
```

重点检查：

- `Sources/CodexQuotaMonitor/Codex/CodexAppServerClient.swift`
- `Sources/CodexQuotaMonitor/Codex/JSONRPCTransport.swift`
- `Sources/CodexQuotaMonitor/Codex/RateLimitModels.swift`
- `Sources/CodexQuotaMonitor/Features/Quota/QuotaViewModel.swift`

---

# 3. 不允许猜协议

不要直接根据当前 `RateLimitParser` 猜测问题。

第一步必须在用户当前 Mac 环境中确认真实协议响应。

先运行：

```bash
codex --version
which codex
```

记录：

- Codex CLI 版本
- 实际可执行文件路径

然后直接启动：

```bash
codex app-server --listen stdio://
```

用 JSON-RPC 完成真实请求。

请求顺序：

### initialize

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "clientInfo": {
      "name": "quota-bar-diagnostic",
      "title": "Quota Bar Diagnostic",
      "version": "0.1"
    },
    "capabilities": {
      "experimentalApi": true
    }
  }
}
```

### initialized

```json
{
  "jsonrpc": "2.0",
  "method": "initialized",
  "params": {}
}
```

### rate limits

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "account/rateLimits/read",
  "params": {
    "excludeResetCreditDetails": true
  }
}
```

必须检查真实返回结构。

## 安全要求

调试时：

- 不打印 access token
- 不打印 `auth.json`
- 不读取认证文件
- 不打印其他敏感凭据
- 可以打印 rate-limit 响应结构
- 如果响应存在 `accountId`，日志中用 `<redacted>` 替代

建议临时增加：

```text
Scripts/diagnose-app-server.py
```

用途仅为：

1. 启动 app-server
2. handshake
3. 调用 `account/rateLimits/read`
4. 输出经过脱敏的 JSON

确认问题后可以保留该脚本作为兼容性诊断工具。

---

# 4. 当前 Parser 需要修正

文件：

```text
Sources/CodexQuotaMonitor/Codex/RateLimitModels.swift
```

当前代码：

```swift
if let grouped = resultObject["rateLimitsByLimitId"]?.objectValue {
    return grouped.compactMap { ... }
}
```

这里存在兼容性问题：

如果：

```json
"rateLimitsByLimitId": {}
```

但：

```json
"rateLimits": {
  ...
}
```

仍然存在有效数据，那么当前代码会直接返回：

```swift
[]
```

不会继续 fallback。

修改成：

```text
1. rateLimitsByLimitId 存在并且解析后至少有一个有效 bucket
   → 使用它

2. rateLimitsByLimitId 为 null / 空对象 / 全部 bucket 无法解析
   → fallback 到 rateLimits

3. rateLimits 仍无法解析
   → 尝试 direct snapshot

4. 全部失败
   → 返回明确的 parser diagnostic
```

不要简单返回空数组并让 UI 猜测原因。

---

# 5. 增加安全的协议诊断信息

当前最大问题之一是：

```text
parser 返回 [] 时，没有任何信息说明真实 response 长什么样。
```

而 `stderr` 又被完全丢弃，因此很难定位兼容问题。

正式程序中增加 DEBUG-only 的安全诊断。

只记录 JSON 的：

- key 名称
- value 类型
- bucket 数量
- 是否存在 primary
- 是否存在 secondary
- `windowDurationMins`
- `usedPercent`
- `resetsAt`

例如：

```text
rateLimit response:
rootKeys = [
  ordinaryUsageAllowed,
  rateLimits,
  rateLimitsByLimitId,
  rateLimitResetCredits
]

rateLimitsByLimitId.count = 2

bucket[codex]:
  primary = true
  secondary = true
  primary.windowDurationMins = 300
  secondary.windowDurationMins = 10080
```

禁止输出认证相关内容。

---

# 6. 修复一个确定存在的 UI bug

文件：

```text
Sources/CodexQuotaMonitor/App/AppState.swift
```

当前：

```swift
return "C (quotaViewModel.menuBarPercentageText)"
```

这是普通字符串，不是 Swift 字符串插值。

应该改为：

```swift
return "C \(quotaViewModel.menuBarPercentageText)"
```

否则菜单栏会显示字面量，而不是额度百分比。

---

# 7. 防止重复刷新

文件：

```text
Sources/CodexQuotaMonitor/Features/Quota/QuotaViewModel.swift
```

当前：

```swift
guard !isRefreshing || manual else { return false }
```

这意味着：

```text
manual == true
```

时，即使已有刷新请求正在执行，也允许再次发起请求。

改成单请求合并策略。

V1 最简单：

```swift
guard !isRefreshing else { return false }
```

不要同时向同一个 app-server 发多个额度刷新。

后续如有必要再做 refresh coalescing。

---

# 8. 统一额度警告阈值

当前存在两个不同规则。

`QuotaViewModel`：

```text
<= 10  critical
<= 50  low
```

`QuotaFormatter`：

```text
<= 10  red
11...25 orange
26...50 yellow
```

统一为：

```text
remaining > 25%    正常
11% ~ 25%          额度偏低
0% ~ 10%           即将耗尽
```

也就是：

```text
normal   > 25
low      11...25
critical <= 10
```

---

# 9. 必须增加测试

当前 `Package.swift` 没有 test target。

增加：

```swift
.testTarget(
    name: "CodexQuotaMonitorTests",
    dependencies: ["CodexQuotaMonitor"]
)
```

如果 executable target 导入测试不方便，可以把纯协议模型和 parser 抽到独立 library target，例如：

```text
CodexQuotaCore
CodexQuotaMonitor
CodexQuotaMonitorTests
```

不要为了测试大规模重构。

至少覆盖以下 fixture。

## Case 1：当前标准结构

```json
{
  "rateLimits": {
    "limitId": "codex",
    "primary": {
      "usedPercent": 20,
      "windowDurationMins": 300,
      "resetsAt": 2000000000
    },
    "secondary": {
      "usedPercent": 40,
      "windowDurationMins": 10080,
      "resetsAt": 2000100000
    }
  },
  "rateLimitsByLimitId": {
    "codex": {
      "limitId": "codex",
      "primary": {
        "usedPercent": 20,
        "windowDurationMins": 300,
        "resetsAt": 2000000000
      },
      "secondary": {
        "usedPercent": 40,
        "windowDurationMins": 10080,
        "resetsAt": 2000100000
      }
    }
  }
}
```

期望：

```text
5 小时剩余 80%
周额度剩余 60%
```

## Case 2：map 为 null

```json
{
  "rateLimitsByLimitId": null,
  "rateLimits": {
    "primary": {
      "usedPercent": 20,
      "windowDurationMins": 300
    }
  }
}
```

必须 fallback 成功。

## Case 3：map 为空

```json
{
  "rateLimitsByLimitId": {},
  "rateLimits": {
    "primary": {
      "usedPercent": 20,
      "windowDurationMins": 300
    }
  }
}
```

必须 fallback 成功。

## Case 4：多 bucket

例如：

```text
codex
base_model_inference
```

必须全部保留。

UI 可以暂时只展示 primary bucket，但 domain model 不允许丢数据。

## Case 5：未知字段

服务端新增任意字段不得导致解析失败。

---

# 10. 请求参数

正式请求建议显式发送：

```json
{
  "excludeResetCreditDetails": true
}
```

理由：

额度挂件只需要 rate-limit snapshot，不需要每 60 秒额外读取完整 reset-credit 明细。

V1 暂时：

```text
supportsLunaReserve
```

不要主动设置，除非确认产品需要该语义。

---

# 11. 错误状态必须区分

不要全部显示：

```text
Codex 服务异常
```

至少区分：

```text
Codex CLI 未安装
Codex 未登录
app-server 启动失败
initialize 失败
rateLimits/read RPC 失败
服务器未返回额度
返回结构无法识别
```

UI 可以保持简洁。

详细原因可以：

- hover
- 菜单栏详情
- DEBUG diagnostics

显示。

---

# 12. 本轮不要做的东西

本轮禁止：

- 重做 UI
- 加历史趋势
- 加图表
- 加通知
- 加网络私有 API fallback
- 读取 `~/.codex/auth.json`
- 加 Electron / Tauri
- 引入第三方库
- 大规模重构
- 为未来 Windows 做抽象

先保证：

```text
用户当前 Mac + 当前 Codex CLI
```

稳定显示真实额度。

---

# 13. 本轮验收标准

必须同时满足：

### A

```bash
swift build
```

通过。

### B

运行：

```bash
swift run CodexQuotaMonitor
```

挂件正常启动。

### C

程序能取得真实：

```text
primary
secondary
```

额度窗口。

如果当前账户实际没有 secondary，则只显示真实存在的窗口。

不得伪造。

### D

对于典型 Plus 账户，如果服务端返回：

```text
windowDurationMins = 300
windowDurationMins = 10080
```

UI 应显示：

```text
5 小时额度
周额度
```

### E

显示：

```text
剩余百分比
重置倒计时
最后更新时间
```

### F

菜单栏百分比不是字面量：

```text
C (quotaViewModel.menuBarPercentageText)
```

而应类似：

```text
C 72%
```

### G

连续手动点击刷新不能产生并发 RPC 请求。

### H

增加 parser 自动测试并通过：

```bash
swift test
```

---

# 14. Codex 执行指令

把本文件放在仓库中后，可以直接对 Codex 说：

> 阅读 `QUOTA_BAR_NEXT_STEP.md`。
>
> 不要继续开发新功能，也不要修改整体 UI。
>
> 先在我的本机环境中完成第 3 节的 app-server 协议诊断，确认当前安装的 Codex CLI 版本和 `account/rateLimits/read` 的真实响应。
>
> 然后根据真实响应修复数据解析，同时完成文档中列出的确定性 bug、并发刷新问题和 parser 测试。
>
> 不要读取 `~/.codex/auth.json`，不要直接调用私有 usage HTTP API。
>
> 完成后运行：
>
> ```bash
> swift build
> swift test
> ```
>
> 再实际启动程序确认挂件能显示真实额度。
>
> 最后把：
>
> 1. 实际 Codex CLI 版本
> 2. 实际响应结构的脱敏摘要
> 3. 根因
> 4. 修改文件
> 5. 测试结果
>
> 写入 `README.md` 的 `Compatibility Notes`。


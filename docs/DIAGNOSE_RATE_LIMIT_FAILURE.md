# Quota Bar — 下一步诊断任务

目标：确认 `account/rateLimits/read` 失败的真实原因。

当前不要修改 UI，不要新增功能，不要改成本地 JSONL 数据源。

## 1. 保留真实 RPC 错误信息

当前 `CodexAppServerClient.swift` 把真实错误统一吞成 `rateLimitsReadFailed`。

请修改为保留：
- JSON-RPC error code
- 脱敏后的 error message
- 是否为 timeout / process exit / broken pipe

例如：

```swift
case rateLimitsReadFailed(code: Int?, message: String)
```

禁止记录 access token、auth.json 内容、account id、user id、cookie、Authorization header。
如果 message 中包含疑似凭据，请替换为 `<redacted>`。

## 2. 修改诊断脚本

文件：

```text
Scripts/diagnose-app-server.py
```

当前只输出 `errorCode`，请增加安全的 `errorMessage`，并区分 initialize error、timeout、app-server process exit、RPC error、success。

不要输出原始完整 response。

## 3. 修复遗漏 bug

文件：

```text
Sources/CodexQuotaMonitor/App/AppState.swift
```

当前：

```swift
return "C (quotaViewModel.menuBarPercentageText)"
```

改为：

```swift
return "C \(quotaViewModel.menuBarPercentageText)"
```

## 4. 运行诊断

```bash
codex --version
which codex
```

无显式代理：

```bash
./Scripts/diagnose-app-server.py
```

HTTP 代理：

```bash
HTTP_PROXY=http://127.0.0.1:7890 \
HTTPS_PROXY=http://127.0.0.1:7890 \
./Scripts/diagnose-app-server.py
```

SOCKS 代理：

```bash
ALL_PROXY=socks5://127.0.0.1:7891 \
./Scripts/diagnose-app-server.py
```

最后：

```bash
swift build
swift run CodexQuotaMonitorTests
```

## 5. 完成后停止开发，只报告结果

请整理：

```text
Codex CLI version:
Codex path:

No proxy:
<诊断结果>

HTTP proxy 7890:
<诊断结果>

SOCKS proxy 7891:
<诊断结果>

swift build:
PASS / FAIL

CodexQuotaMonitorTests:
PASS / FAIL
```

如果成功返回额度，再补充：

```text
rateLimitsByLimitId count:
primary windowDurationMins:
primary usedPercent:
secondary windowDurationMins:
secondary usedPercent:
```

## 给 Codex 的执行指令

阅读 `DIAGNOSE_RATE_LIMIT_FAILURE.md` 并严格执行。

本轮目标只有一个：确定 `account/rateLimits/read` 失败的真实原因。

不要优化 UI，不要实现本地 JSONL fallback，不要新增功能。

先保留并脱敏输出真实 RPC 错误，然后分别在：
1. 无显式代理
2. HTTP_PROXY/HTTPS_PROXY = `http://127.0.0.1:7890`
3. ALL_PROXY = `socks5://127.0.0.1:7891`

三种环境下运行诊断脚本。

完成后停止开发，把诊断结果汇总给我，不要根据猜测继续修代码。

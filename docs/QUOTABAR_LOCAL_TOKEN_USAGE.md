# QuotaBar — 本地 Token 使用监控

目标仓库：`xzcode/quota-bar`

本轮只做两件事：

1. 统计**今日本机 Codex Token 使用量**
2. 用真实 Token 活动驱动 Compact Energy Bar，解决“Codex 已经在工作，但中途打开 QuotaBar 没有粒子”的问题

不要修改 app-server、JSON-RPC、额度解析、Reserve、5 小时/周额度规则和 Expanded 主布局。

---

## 1. 当前问题

当前粒子依赖 QuotaBar 自己观察到两次 rate-limit snapshot 之间 `usedPercent` 增加，然后固定播放约 30 秒。

这会导致：

```text
Codex 已经工作了一段时间
→ 中途启动 QuotaBar
→ 没有新的前后 quota snapshot 可比较
→ isParticlePulseActive = false
→ 没有粒子
```

这并不能准确表达“Codex 当前正在消耗 Token”。

---

## 2. 新的数据职责

```text
codex app-server
→ 5 小时 / 周额度
→ 剩余百分比 / 重置时间
→ 决定 normal / low / critical 颜色

~/.codex/sessions
→ token_count
→ 今日 Tokens / 最近 Tokens per minute
→ 决定 calm / active / fast / veryFast 动效
```

不要再使用额度百分比变化作为粒子主数据源。

---

## 3. 本地数据来源

读取：

```text
~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl
```

只解析 `token_count` 事件中的：

```text
info.total_token_usage.total_tokens
info.total_token_usage.input_tokens
info.total_token_usage.cached_input_tokens
info.total_token_usage.output_tokens
```

忽略其他 prompt、response、tool output 等内容，也不要写入日志。

`cached_input_tokens` 是 breakdown 信息，不要再与 input/output 相加计算 total。总量优先使用 `total_tokens`。

---

## 4. 新增模型

建议在 `CodexQuotaCore` 增加：

```swift
public enum TokenActivityLevel: String, Codable, Sendable {
    case calm
    case active
    case fast
    case veryFast
}

public struct LocalTokenUsageSnapshot: Sendable, Equatable {
    public let capturedAt: Date
    public let todayTotalTokens: Int64
    public let todayInputTokens: Int64
    public let todayCachedInputTokens: Int64
    public let todayOutputTokens: Int64
    public let recentTokensPerMinute: Double
    public let lastUsageAt: Date?
    public let activityLevel: TokenActivityLevel
}
```

Token activity 与现有基于额度百分比的 `BurnRateLevel` 分开，不要混成一个概念。

---

## 5. 新增服务

建议：

```text
Sources/QuotaBar/Services/
  LocalTokenUsageMonitor.swift
  RolloutTokenParser.swift
```

职责：

- 发现近期 rollout 文件
- 解析 token_count
- 计算今天的本机 Token
- 计算最近 Tokens/min
- 增量 tail 活跃文件
- 输出 `LocalTokenUsageSnapshot`

所有文件 IO / JSON 解析放后台 task，不要阻塞 MainActor。

---

## 6. TokenCount 是累计值，不能直接相加

例如同一 session：

```text
10:00  total = 100K
10:05  total = 180K
10:10  total = 250K
```

今日新增应该是：

```text
250K
```

不是：

```text
530K
```

每个 rollout/session 按相邻累计值计算：

```text
delta = currentTotal - previousTotal
```

仅记录正向 delta。

---

## 7. 今日新 Session

如果 session 今天开始，第一条：

```text
total = 120K
```

则今日可以计：

```text
120K
```

---

## 8. 跨午夜必须正确

例如：

```text
昨天 23:59 total = 1.20M
今天 00:05 total = 1.40M
```

今天只计：

```text
200K
```

不能计 1.40M。

“今天”使用 `Calendar.current` / 用户本地时区，不按 UTC。

---

## 9. 不能只扫描今天目录

rollout 路径日期表示 session 创建日期，一个昨天甚至更早创建的 session 今天仍可能继续写。

启动时至少发现：

- 今天创建的 rollout
- 昨天创建的 rollout
- 任何 `modificationDate >= 今天 00:00` 的旧 rollout

可以递归 enumerate 一次并按 mtime 过滤。

不要周期性全文扫描全部历史文件。

---

## 10. 启动扫描 + 增量读取

启动时：

```text
发现 candidate files
→ 扫描 token_count
→ 计算今日累计
→ 计算最近 activity
→ 保存每个文件 byteOffset
```

随后只读取新增字节。

建议维护：

```swift
struct RolloutTailState {
    let url: URL
    var byteOffset: UInt64
    var partialLine: Data
    var lastTotalTokens: Int64?
}
```

JSONL 最后一行可能还没写完，只解析完整换行结束的行；半行留到下次。

如果文件 size 小于旧 offset，安全重建该文件状态。

---

## 11. 监听策略

V1 优先简单、可靠、省电：

```text
活跃文件 size/mtime 检查：2 秒
新文件 rescan：10~15 秒
```

只 stat 少量近期文件。

禁止：

```text
每 2 秒递归扫描全部 ~/.codex/sessions
每 2 秒全文 parse JSONL
```

如使用系统原生 FSEvents 且实现更可靠，也可以，但不要引入第三方 watcher。

---

## 12. 最近 Token Activity

维护最近约 5 分钟的内存 delta events：

```swift
struct TokenDeltaEvent {
    let timestamp: Date
    let totalTokens: Int64
}
```

活动速率使用最近 2 分钟：

```text
recentTokensPerMinute
= 最近 2 分钟 Token 正增量 / 2
```

如果最近 90 秒完全没有 Token 正增量：

```text
activityLevel = calm
```

---

## 13. 中途打开必须恢复动画

这是核心验收项。

QuotaBar 启动扫描历史时，如果发现最近 90 秒仍有真实 Token 增量：

```text
立即计算 activityLevel
→ active / fast / veryFast
→ 直接挂载 DynamicEnergyLayer
```

不能等 QuotaBar 自己再观察到下一次额度百分比变化。

---

## 14. 初始 Activity 阈值

先集中定义，方便之后根据真实使用调整：

```text
calm
最近 90 秒无 Token 增量

active
0 < tokens/min < 100K

fast
100K <= tokens/min < 500K

veryFast
>= 500K tokens/min
```

例如：

```swift
enum TokenActivityPolicy {
    static let fastThreshold = 100_000.0
    static let veryFastThreshold = 500_000.0
}
```

这些只是 QuotaBar 的视觉参数，不是 OpenAI/Codex 的官方额度规则。

---

## 15. 防止视觉抖动

用 rolling 2 分钟 rate，不要只看单次请求。

允许给 active/fast/veryFast 约 10~20 秒最短视觉保持时间。

但如果最近 90 秒完全没 Token 活动，必须回到 calm。

---

## 16. Compact Bar 改造

当前主控制：

```text
isParticlePulseActive
+ BurnRateLevel
```

改为：

```text
LocalTokenUsageSnapshot.activityLevel
```

动态层条件：

```text
activityLevel != calm
&& !isStale
&& !reduceMotion
```

旧 `startParticleActivityPulse()` 不再作为 Energy Bar 主控制逻辑。

可以先保留旧代码以降低重构风险，但 UI 不再依赖它。

---

## 17. 动画映射

继续复用现有：

```text
StaticEnergyBackground
DynamicEnergyLayer
EnergyRibbonView
ParticleFlowView
MovingHighlight
Comet Trails
```

只更换活动数据源。

```text
calm     → 0 FPS / 无 DynamicEnergyLayer
active   → 12 FPS
fast     → 18 FPS
veryFast → 24 FPS
```

额度剩余仍只负责 danger color：

```text
>25%   normal
11~25% low
<=10%  critical
```

---

## 18. Expanded 显示“今日 Token”

当前：

```text
◉ 消耗速度：平稳
```

建议改成一行：

```text
◉ 平稳                     今日 18.6M
```

有活动：

```text
◉ 活跃                     今日 18.6M
◉ 较快                     今日 18.6M
◉ 很快                     今日 18.6M
```

这里的“今日”明确指**今日本机 Codex**。

---

## 19. Token 格式

新增 formatter：

```text
523        → 523
1,240      → 1.2K
52,300     → 52.3K
1,240,000  → 1.24M
18,630,000 → 18.6M
```

不要显示过多小数。

---

## 20. 今日 Token Tooltip

Hover “今日 18.6M” 可显示：

```text
今日本机 Codex Token

总计：18.63M
输入：15.20M
缓存输入：11.82M
输出：3.43M

当前：185K/min
```

不要暗示 breakdown 相加等于 total。

---

## 21. Token 数据不可用

如果：

```text
~/.codex/sessions 不存在
没有 token_count
读取失败
```

不要影响额度功能，也不要显示红色主错误。

UI：

```text
今日 —
```

Activity：

```text
calm
```

诊断信息可增加：

```text
localTokenUsage=unavailable
```

---

## 22. 隐私

QuotaBar 只允许解析和缓存 Token 统计。

禁止保存或输出：

- prompt
- assistant response
- tool output
- 用户文件内容
- session 原文

---

## 23. 午夜处理

本地跨到 00:00 时：

```text
today aggregate 归零
```

但保留每个活跃 session 的上一条累计值作为 baseline，确保跨午夜 delta 正确。

---

## 24. 测试

至少覆盖：

1. 累计值 `100K → 180K → 250K` 得到 250K，而不是 530K
2. 今日新 session 第一条 120K → 今日 120K
3. 跨午夜 1.20M → 1.40M → 今日 200K
4. 多 session 正确相加
5. malformed JSON 忽略不 crash
6. incomplete last line 下次补全后解析
7. unknown fields 忽略
8. 最近 60 秒有 usage → activity 非 calm
9. 90 秒无 usage → calm
10. Token 数据不可用不影响 quota snapshot

---

## 25. 实测验收

### 中途启动

```text
1. QuotaBar 未运行
2. Terminal 中 Codex 持续工作
3. Codex 仍在生成/执行时启动 QuotaBar
```

期望：

```text
startup scan 检测最近 Token 增量
→ 立即出现 Energy Flow
```

不需要等待额度百分比变化。

### 空闲

停止 Codex 后等待 90 秒：

```text
activityLevel = calm
DynamicEnergyLayer 卸载
TimelineView 不存在
0 FPS
```

---

## 26. 本轮不要做

禁止新增：

- 云端账号级 Token 统计
- 跨设备统计
- Token 图表
- 按模型统计
- 成本估算
- 通知
- SQLite
- 私有 usage HTTP API
- auth.json 读取

先把**今日本机 Token + 实时 Token Activity**做准确。

---

## 27. 完成后运行

```bash
swift build
swift run QuotaBarTests
git diff --check
swift run QuotaBar
```

---

## 28. 完成后汇报

完成后停止开发，并汇报：

```text
1. LocalTokenUsageMonitor 架构
2. rollout 文件发现策略
3. 增量读取策略
4. 今日 Token 算法
5. 跨午夜算法
6. recent Tokens/min 算法
7. activity 阈值
8. 中途启动如何恢复 activity
9. Compact Bar 是否已脱离 usedPercent pulse
10. 今日 Token UI
11. build / tests / diff check
12. 中途启动动画实测
13. 空闲 90 秒后 0 FPS 实测
```

---

## 给 Codex 的执行指令

阅读 `QUOTABAR_LOCAL_TOKEN_USAGE.md` 并严格执行。

本轮核心目标：

```text
读取 ~/.codex/sessions 中的 token_count
→ 统计今日本机 Token
→ 计算最近 Tokens/min
→ 用真实 Token activity 驱动 Compact Energy Bar
```

重点修复：

```text
Codex 已经在运行时，中途打开 QuotaBar 没有粒子效果
```

完成后必须实测：

```text
中途启动 + 最近有 Token 使用 → 自动出现 Energy Flow
停止使用 90 秒 → calm → 0 FPS
```

不要增加其他产品功能。

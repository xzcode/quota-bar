# Quota Bar — Collapsed / Expanded UI Spec

版本：V1 UI Polish  
目标平台：macOS 14+  
技术栈：Swift 6 + SwiftUI + AppKit  
适用仓库：`xzcode/quota-bar`

## 1. 设计目标

Quota Bar 不应只是一个静态额度面板，而应成为一个“常驻桌面的活性额度指示器”。

核心交互：

```text
收纳态：一根细长的动态额度条
        ↓ 点击
展开态：显示 5 小时额度 / 周额度 / 重置时间 / 状态详情
```

收纳态负责“扫一眼就知道情况”，展开态负责“查看完整信息”。

## 2. 产品视觉概念

收纳态的视觉参考：

- 胶囊形细长条
- 蓝紫渐变
- 内部有少量漂浮粒子
- 消耗速度越快，颜色越偏亮紫 / 粉紫
- 消耗速度越快，粒子移动越快
- 剩余百分比应清晰可读
- 不要做成游戏血条
- 不要有复杂边框
- 不要使用高频闪烁

整体感觉：安静、轻量、有活性、原生 macOS、未来感但不过度科幻。

## 3. 两种显示状态

### 3.1 Collapsed State

默认状态，推荐尺寸：

```text
width: 240 pt
height: 28 pt
cornerRadius: 14 pt
```

示意：

```text
╭────────────────────────────────╮
│  ● ●      62%          ●     ● │
╰────────────────────────────────╯
```

实际视觉：整体为渐变胶囊，少量粒子在内部缓慢漂浮，百分比居中，字号小但清晰，整体不可太亮。

### 3.2 Expanded State

推荐尺寸：

```text
width: 330 pt
height: 190 ~ 210 pt
cornerRadius: 20 pt
```

结构：

```text
┌──────────────────────────────────┐
│ Codex                      ↻  ··· │
│                                  │
│ 5 小时额度              62% 剩余 │
│ ███████████████░░░░░░░░░░░░░░░  │
│ 56 分钟后重置                    │
│                                  │
│ 周额度                  79% 剩余 │
│ ████████████████████░░░░░░░░░░  │
│ 4 天 8 小时后重置                │
│                                  │
│ ● 正常                 刚刚更新  │
└──────────────────────────────────┘
```

## 4. 收纳态信息规则

如果存在 5 小时窗口，收纳态按“5 小时、周额度”的顺序显示百分比，例如：

```text
95% · 76%
```

若没有 5 小时窗口，维持原有行为，仅显示最低剩余百分比。收纳态不显示额度名称、重置时间或状态文字。

如果服务端同时返回 GPT Reserve 窗口，且 5 小时与周额度都为 0%，则收纳态只显示 Reserve：

```text
R · 92%
```

Reserve 仅用于额度显示，不触发模型切换或额度兑换。

## 5. 收纳态使用哪个额度

默认显示两个窗口中 `remainingPercent` 更低的那个。

例如：

```text
5 小时额度：62%
周额度：79%
```

收纳态在有 5 小时窗口时显示 5 小时和周额度的百分比，渐变颜色仍使用最低的普通额度计算。如果两项普通额度均耗尽且存在 Reserve 窗口，则只显示 Reserve 百分比，渐变颜色改按 Reserve 计算。如果没有 5 小时窗口，则只显示最低剩余百分比。

如果：

```text
5 小时额度：85%
周额度：21%
```

则显示 `85% · 21%`，并仍以 `21%` 作为渐变颜色依据。

即：

```swift
collapsedRemaining = min(primaryRemaining, secondaryRemaining) // Used for visual severity.
```

这样收纳态天然代表当前最危险额度。

## 6. Hover 行为

收纳态 hover 时：

- 亮度轻微提升
- 粒子透明度略微提高
- 显示 tooltip：`5 小时：62% / 周额度：79%`

不要自动展开完整卡片。

## 7. 点击与拖动

Collapsed：单击展开。  
Expanded：点击收起按钮或 header 空白区域收起。

不要强制“点击外部即收起”，因为这是桌面常驻挂件，不是 popover。

Collapsed 和 Expanded 都必须支持拖动空白区域移动挂件。按钮、菜单不应抢占拖动事件。

## 8. 展开 / 收起动画

目标：自然、连续、快速、不弹跳。

时长：`220 ~ 280 ms`。

推荐：

```swift
.animation(.spring(response: 0.28, dampingFraction: 0.88))
```

不要整体 scale、bounce 或高幅度 fade。

建议：窗口 frame 平滑变化、内容轻微 crossfade、cornerRadius 小幅变化。

Collapsed：`240 × 28`
Expanded：`330 × ~200`

动画时窗口顶部位置尽量保持不跳动。

## 9. Burn Rate 概念

新增“额度消耗速度”。

必须区分：

```text
remainingPercent = 安全程度
burnRate = 当前消耗活跃程度
```

不要直接用 remainingPercent 控制所有视觉效果。

## 10. Burn Rate 数据模型

基于最近成功 snapshot，保存：

```text
timestamp
bucketId
windowKind
usedPercent
```

建议保留最近 30~60 分钟，不需要数据库，使用 UserDefaults 或小型 JSON cache 即可。

## 11. Burn Rate 计算

默认以当前最危险窗口作为收纳态 burn rate 来源。

计算：

```text
deltaUsedPercent / deltaMinutes
```

例如：

```text
10 分钟前 used = 20
现在 used = 24
burnRate = 4 / 10 = 0.4 % / min
```

为了 UI 稳定，不使用单次瞬时变化，建议取最近 10 分钟窗口。

样本不足时：`burnRate = unknown`，视觉按 calm 处理。

## 12. Burn Rate 等级

V1 使用四档：

```text
calm
active
fast
veryFast
```

建议初始阈值：

```text
calm:    < 0.05 % / min
active:  0.05 ~ 0.15 % / min
fast:    0.15 ~ 0.35 % / min
veryFast: > 0.35 % / min
```

阈值必须集中定义，例如：

```swift
enum BurnRateLevel {
    case calm
    case active
    case fast
    case veryFast
}
```

后续根据真实使用再调，不要散落 magic number。

## 13. 剩余额度状态

保持：

```text
remaining > 25% → normal
11% ~ 25%      → low
<= 10%         → critical
```

## 14. 颜色系统

颜色由两个因素共同决定：

```text
base color = remaining state
animation intensity = burnRate
```

### Normal

`remaining > 25%`，基础渐变为冷蓝 → 蓝紫，避免高饱和霓虹蓝。

### Low

`remaining 11% ~ 25%`，渐变为紫 → 暖紫 → 少量橙，仍保留蓝紫识别。

### Critical

`remaining <= 10%`，渐变为深紫 → 红紫，允许非常轻微的 brightness pulse，禁止闪烁。

### Burn Rate 对颜色的影响

burn rate 不直接改变危险等级颜色，而是控制：

- gradient movement
- highlight intensity
- particle speed
- particle count
- particle opacity

## 15. 粒子系统

不要引入第三方粒子库。

建议使用 SwiftUI 原生实现，Collapsed 推荐约 10 个粒子，总数不超过 16。

单个粒子：

```text
diameter: 1 ~ 3 pt
opacity: 0.25 ~ 0.85
blur: 0 ~ 1.5
shape: Circle
```

粒子主要 `left → right` 流动，附加轻微上下漂移。不要做 Brownian motion、雪花、星空或烟花效果。

## 16. 粒子速度

建议：

```text
calm:     8 ~ 14 s 穿过整条
active:   5 ~ 8 s
fast:     3 ~ 5 s
veryFast: 1.8 ~ 3 s
```

每个粒子速度允许 ±20% 差异。

数量建议：

```text
calm: 6 ~ 8
active: 8 ~ 10
fast: 10 ~ 12
veryFast: 12 ~ 14
```

## 17. 性能要求

这是桌面常驻应用。目标：idle CPU 接近 0，动画 CPU 很低，内存小。

不要使用：

```text
60 FPS Timer
CADisplayLink 常驻
复杂 shader
Metal
SpriteKit
```

优先：

```text
TimelineView(.animation)
Canvas
SwiftUI animation
```

如果 Canvas CPU 明显偏高，则改为少量独立 `Circle + offset animation`。

性能优先于炫技。

## 18. Reduced Motion

必须支持 `accessibilityReduceMotion`。

开启“减少动态效果”后：

- 粒子停止
- gradient movement 停止
- expand/collapse 改为短淡入淡出
- 额度功能不受影响

## 19. 收纳态文字

百分比：`62%`

建议：

```swift
.font(.system(size: 11...12, weight: .semibold, design: .rounded))
.monospacedDigit()
```

颜色使用高可读性的白色，并可加极轻 shadow。

百分比位置 V1 先居中。

## 20. 展开态视觉规则

继续使用现有 macOS material：

```swift
.ultraThinMaterial
```

### Header

```text
Codex                      ↻   ···
```

Codex 使用 title3 / semibold。刷新中只让 refresh icon 旋转。

### Quota Row

每组：

```text
5 小时额度              62% 剩余
[progress bar]
56 分钟后重置
```

不要默认显示绝对时间。绝对时间放 tooltip，例如 `2026-09-23 01:40`。

### Progress Bar

当前进度条太弱。建议：

```text
height = 5 ~ 6 pt
cornerRadius = 3
```

剩余量作为填充比例。背景轨道：`white.opacity(0.08 ~ 0.12)`。

### Footer

保持：

```text
● 正常                    刚刚更新
```

状态颜色：normal=green，low=orange，critical/error=red。

## 21. Burn Rate 在展开态中的显示

V1 不做复杂图表。

可增加一行轻量文案：

```text
消耗速度：平稳
```

映射：

```text
calm → 平稳
active → 活跃
fast → 较快
veryFast → 很快
```

不要直接显示 `%/min` 给普通用户。

## 22. Error State

Collapsed：如果有缓存，继续显示缓存百分比，但降低饱和度，并加一个 small warning dot。完全无数据时显示 `—`。

Expanded：有缓存则显示旧额度，footer 显示 `● 数据可能已过期 / 8 分钟前`。没有缓存则显示“额度暂时不可用 + 简短错误”。

完整 RPC 诊断信息放菜单项“复制诊断信息”，不要直接塞进主 UI。

## 23. Window 技术实现

不要创建两个窗口。继续使用一个 `NSPanel`。

新增：

```swift
enum WidgetPresentationState {
    case collapsed
    case expanded
}
```

状态变化时修改 `NSPanel frame` 并切换内容。

保持现有：

```text
borderless
nonactivatingPanel
transparent
movableByWindowBackground
canJoinAllSpaces
fullScreenAuxiliary
```

收纳态不要获取 keyboard focus。

## 24. Frame Anchor

展开 / 收起必须视觉位置稳定，推荐保持顶部锚点不变。

目标：用户点开时，挂件像“向下展开”，而不是整个窗口跳走。

## 25. 组件建议

建议逐步新增：

```text
Features/
  Widget/
    CompactQuotaBar.swift
    ExpandedQuotaView.swift
    WidgetContainerView.swift
    ParticleFlowView.swift
    BurnRateIndicator.swift
```

不要一次性大规模改目录。

Model 建议：

```swift
struct QuotaUsageSample {
    let timestamp: Date
    let usedPercent: Int
}

struct BurnRateSnapshot {
    let percentPerMinute: Double?
    let level: BurnRateLevel
}
```

## 26. 重置检测

当 `resetsAt` 改变或 `usedPercent` 突然明显下降，说明窗口已重置。

此时清空该 window 的 burn-rate 历史。

不要把 `80% → 2%` 算成负 burn rate。

## 27. 数据刷新频率

保持 60 秒即可。

不要为了粒子动画提高 app-server 刷新频率。动画基于最近一次 burnRate 状态持续运行即可。

## 28. 状态持久化

保存 `collapsed / expanded`。

应用重新启动后恢复用户上次状态。

## 29. Context Menu

Collapsed 右键：

```text
展开
立即刷新
始终置顶
设置
退出
```

Expanded：

```text
收起
立即刷新
始终置顶
设置
退出
```

## 30. 动画原则

允许：

```text
gradient flow
particles
refresh rotation
expand/collapse
subtle warning pulse
```

禁止：

```text
bounce
shake
flash
large glow
continuous scale
heavy blur animation
```

## 31. V1 验收标准

### Collapsed

- [ ] 默认可收纳成细长 bar
- [ ] 显示最低 remainingPercent
- [ ] 蓝紫渐变
- [ ] 少量漂浮粒子
- [ ] burn rate 越高粒子越快
- [ ] burn rate 越高渐变动态越明显
- [ ] 点击可展开
- [ ] 可拖动
- [ ] 状态重启后保留

### Expanded

- [ ] 显示 5 小时额度
- [ ] 显示周额度
- [ ] 显示 remainingPercent
- [ ] 显示 reset countdown
- [ ] 显示 last updated
- [ ] 显示 burn rate 文案
- [ ] 可收起
- [ ] 刷新按钮正常
- [ ] 菜单正常

### Data

- [ ] burn rate 基于真实历史 snapshot
- [ ] reset 后历史清空
- [ ] 无数据时不伪造 burn rate
- [ ] 不增加 app-server 刷新频率

### Performance

- [ ] idle CPU 占用非常低
- [ ] 粒子数量 <= 16
- [ ] 不引入第三方动画库
- [ ] Reduced Motion 可禁用动态效果

## 32. Codex 实现顺序

必须按顺序实现。

### Phase 1 — Presentation State

先完成：

```text
collapsed / expanded
NSPanel resize
状态持久化
click expand/collapse
```

暂时不要粒子。

### Phase 2 — Compact Visual

实现：

```text
gradient capsule
percentage
hover
tooltip
drag
context menu
```

暂时使用固定动画速度。

### Phase 3 — Burn Rate

实现：

```text
history samples
burn rate calculator
reset detection
level mapping
```

并增加测试。

### Phase 4 — Particle Flow

实现 `ParticleFlowView`，让 `burnRateLevel` 控制：

```text
particle speed
particle count
gradient movement
```

### Phase 5 — Expanded Polish

优化：

```text
progress bars
reset text
footer
burn rate label
error state
```

## 33. 给 Codex 的执行指令

阅读 `UI_SPEC_BAR_EXPAND.md`。

当前数据链路已经正常，不要修改 `account/rateLimits/read` 协议逻辑，除非 UI 工作发现明确 bug。

严格按照：

```text
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
```

实现。

先只完成 Phase 1：

1. 新增 collapsed / expanded presentation state
2. 单个 NSPanel 支持两种 frame
3. 点击收纳态展开
4. 展开态支持收起
5. 两种状态都保持可拖动
6. 保存并恢复 presentation state
7. 展开 / 收起时窗口顶部位置不能明显跳动
8. 使用轻量 spring animation
9. 不实现粒子
10. 不实现 burn rate

完成后运行：

```bash
swift build
swift run QuotaBarTests
```

然后实际启动程序确认：

```text
收纳
展开
拖动
重启恢复
```

均正常。

Phase 1 完成后停止，不要自动继续 Phase 2。

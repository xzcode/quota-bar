# Quota Bar — Phase 2: Compact Visual

适用仓库：`xzcode/quota-bar`  
前置条件：Phase 1 已完成  
本阶段目标：把收纳态从“一个有百分比的毛玻璃 Capsule”做成真正具有产品辨识度的额度条。

> 本阶段 **不实现 Burn Rate，不实现粒子系统，不修改额度数据链路**。

---

## 1. 当前状态

Phase 1 已实现：

- 单个 `NSPanel`
- collapsed / expanded 两种状态
- 点击展开
- 展开后可收起
- presentation state 持久化
- frame 动画
- 窗口位置持久化
- 原有额度详情继续工作

当前 collapsed UI 仍然是：

```text
普通 ultraThinMaterial Capsule
        62%
```

Phase 2 要把它升级为：

```text
蓝紫渐变动态额度条
        62%
```

视觉目标参考：

```text
╭────────────────────────────────╮
│     ·            62%       ·   │
╰────────────────────────────────╯
```

注意：本阶段示意中的点不是真正粒子系统；粒子留到 Phase 4。

---

# 2. 收纳态尺寸

保持：

```text
width = 240 pt
height = 28 pt
cornerRadius = 14 pt
```

如果当前 `WidgetPresentationState.collapsed.panelSize` 已经是这个尺寸，则不要改。

如果不是，以：

```swift
CGSize(width: 240, height: 28)
```

为目标。

---

# 3. 背景结构

不要继续使用纯：

```swift
.background(.ultraThinMaterial, in: Capsule())
```

收纳条应有自己的颜色层。

建议层级：

```text
ZStack
├── dark translucent base
├── blue → violet gradient
├── subtle moving highlight
├── optional faint glass/material overlay
├── percentage text
└── thin border
```

推荐 SwiftUI 结构：

```swift
ZStack {
    Capsule()
        .fill(baseBackground)

    Capsule()
        .fill(mainGradient)

    movingHighlight

    percentageText
}
.clipShape(Capsule())
```

---

# 4. 基础渐变

Normal 状态先固定使用蓝紫渐变。

不要在 Phase 2 根据 burn rate 改颜色。

视觉方向：

```text
left:
cool blue / periwinkle

middle:
indigo

right:
violet
```

建议大致色相：

```text
#6F8CFF
#7668FF
#9A42F4
```

不要求严格使用这三个 HEX，可根据 macOS 实际显示做微调。

要求：

- 不要过度饱和
- 不要纯 neon
- 不要明显粉红
- 不要大面积纯紫
- 桌面深色 / 浅色背景都要有辨识度

SwiftUI 可以用：

```swift
LinearGradient(
    colors: [...],
    startPoint: .leading,
    endPoint: .trailing
)
```

---

# 5. 渐变透明度

Quota Bar 是常驻桌面的，不应像广告 Banner 一样抢眼。

Normal 建议：

```text
gradient opacity ≈ 0.78 ~ 0.9
```

底部可保留一点 material 感。

不要做到完全不透明。

---

# 6. Moving Highlight

Phase 2 可以有非常轻的“能量流动感”，但不是 Burn Rate。

只实现固定速度。

例如：

```text
一条宽约 60~100 pt 的淡色 highlight
从右向左缓慢穿过
```

效果：

```text
████▒▒████████████
      →
```

要求：

```text
duration ≈ 8 ~ 12 s
opacity ≈ 0.08 ~ 0.16
```

循环：

```text
linear
repeatForever
```

不要快速扫光。

不要做明显白色光柱。

---

# 7. Highlight 形式

推荐：

```swift
LinearGradient(
    colors: [
        .clear,
        .white.opacity(0.12),
        .clear
    ],
    startPoint: .leading,
    endPoint: .trailing
)
```

宽度小于 bar。

通过 offset 动画：

```text
-x
→
barWidth + x
```

---

# 8. Reduced Motion

如果：

```swift
@Environment(\.accessibilityReduceMotion)
```

为 true：

```text
停止 moving highlight
```

保留静态 gradient。

---

# 9. Percent Text

继续显示：

```text
62%
```

不要加：

```text
剩余
5h
Codex
```

字体建议：

```swift
.font(.system(size: 11.5, weight: .semibold, design: .rounded))
.monospacedDigit()
```

如果 Swift 不方便使用 11.5：

```text
11 或 12 都可
```

颜色：

```text
.white.opacity(0.95)
```

可以加极轻 shadow：

```swift
.shadow(color: .black.opacity(0.18), radius: 1, y: 1)
```

---

# 10. 百分比来源

继续使用：

```swift
viewModel.menuBarPercentageText
```

前提是它表示：

```text
所有额度窗口中 remainingPercent 最低值
```

不要另写一套计算。

例如：

```text
5h 62%
weekly 79%

Collapsed = 62%
```

---

# 11. 无数据状态

如果：

```text
menuBarPercentageText == "—"
```

收纳态显示：

```text
—
```

背景：

```text
desaturated gray-violet
```

此时 moving highlight 停止。

不要显示红色整条 bar。

---

# 12. 缓存 / stale 状态

如果已有缓存但在线刷新失败：

- 继续显示缓存百分比
- gradient 饱和度降低约 20%
- 在右侧增加一个非常小的 warning dot

例如：

```text
             62%          •
```

Dot：

```text
diameter = 4 pt
orange
```

不要改变整体布局。

---

# 13. Critical / Low 颜色

虽然 Burn Rate 尚未实现，但 Phase 2 可以根据 `remainingPercent` 改静态基色。

规则继续使用：

```text
> 25%
normal

11...25%
low

<= 10%
critical
```

## Normal

```text
blue → violet
```

## Low

仍然保留蓝紫 identity，只加入少量暖色：

```text
indigo → violet → warm violet
```

不要纯橙。

## Critical

```text
deep violet → magenta-red
```

不要整条亮红。

---

# 14. 不要使用 Progress Fill

Collapsed bar **不是传统进度条**。

不要做：

```text
左侧 62% 有颜色
右侧 38% 灰色
```

整个 capsule 都有渐变。

百分比数字负责表达剩余量。

这样更符合我们要的“活性能量条”，也避免和展开态 progress bar 重复。

---

# 15. Hover

鼠标进入收纳态：

```text
brightness + 5~8%
border opacity + 少量
```

不要 scale。

不要改变尺寸。

鼠标离开恢复。

动画：

```text
0.12 ~ 0.18 s easeOut
```

---

# 16. Tooltip

Hover tooltip：

```text
5 小时：62%
周额度：79%
```

数据不存在的窗口不要伪造。

如果只有一个窗口：

```text
5 小时：62%
```

实现方式可以继续使用 `.help(...)`。

需要新增 ViewModel helper，例如：

```swift
var collapsedTooltipText: String
```

不要在 View 中直接拼业务逻辑。

---

# 17. 点击与拖动

当前 collapsed：

```swift
.onTapGesture {
    appState.setPresentationState(.expanded)
}
```

必须保证：

- 单击仍然展开
- 拖动仍然移动窗口
- 拖动结束不能误触发展开

如果当前 `NSPanel.isMovableByWindowBackground` 与 SwiftUI `onTapGesture` 实测存在冲突，优先保证：

```text
拖动手感
```

可使用 AppKit gesture 区分 click / drag，但不要为了 Phase 2 过度工程化。

验收时必须手测：

```text
click → expand
drag → move only
```

---

# 18. Context Menu

Collapsed 添加右键菜单：

```text
展开
立即刷新
────────
始终置顶
设置
────────
退出
```

其中：

```text
始终置顶
```

需要显示当前 checked state。

可用：

```swift
Toggle(...)
```

或等效 Menu item。

不要把 context menu 和左键展开混在一起。

---

# 19. Expanded UI 本阶段不要重做

Phase 2 只允许对 Expanded 做一个改动：

```text
如果需要，为收纳/展开过渡调整背景兼容性
```

不要：

- 改 progress bar
- 改 footer
- 改 reset 信息
- 加 burn rate
- 加 charts
- 加 particles

这些留给后面。

---

# 20. 文件结构

建议新增：

```text
Sources/QuotaBar/Features/Widget/
    CompactQuotaBar.swift
```

如果需要：

```text
CompactQuotaBarStyle.swift
```

但不要拆太碎。

`QuotaWidgetView.swift` 应主要负责：

```text
collapsed / expanded routing
```

例如：

```swift
if presentationState == .collapsed {
    CompactQuotaBar(...)
} else {
    expandedContent
}
```

---

# 21. 性能要求

Moving highlight 必须很轻。

不要使用：

```text
Timer 60fps
CADisplayLink
SpriteKit
Metal
第三方动画库
```

优先：

```text
SwiftUI animation
```

收纳状态长期运行 10 分钟后：

```text
CPU 不应持续明显占用
风扇不应因此启动
```

---

# 22. 视觉验收

Phase 2 完成后，收纳态应达到：

```text
第一眼：
这是一个精致的状态条

第二眼：
我能看到 62%

Hover：
能快速知道 5h / weekly

点击：
自然展开
```

不应该像：

```text
ProgressView
Button
普通 Material Capsule
```

---

# 23. 功能验收

必须手测：

- [ ] 正常额度显示蓝紫渐变
- [ ] low 状态有视觉变化
- [ ] critical 状态有视觉变化
- [ ] 无数据显示 `—`
- [ ] stale cache 有小 warning dot
- [ ] hover 有轻微反馈
- [ ] tooltip 正确显示两个额度
- [ ] 单击展开
- [ ] 拖动不误展开
- [ ] 右键 context menu 正常
- [ ] Reduced Motion 停止 moving highlight
- [ ] 收纳 / 展开状态持久化不受影响
- [ ] 原有额度读取完全不受影响

---

# 24. 自动检查

完成后运行：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

全部必须通过。

---

# 25. Codex 执行指令

阅读 `UI_PHASE2_COMPACT_VISUAL.md`。

只实现 Phase 2。

当前额度数据链路已经验证正常：

```text
5 小时额度
周额度
reset time
account/rateLimits/read
```

不要修改 Codex app-server / JSON-RPC / parser 逻辑。

本阶段只完成：

1. 提取 `CompactQuotaBar`
2. 蓝紫渐变 Capsule
3. 固定速度、非常轻微的 moving highlight
4. remaining 状态对应静态颜色变化
5. percentage text
6. hover feedback
7. tooltip
8. stale warning dot
9. no-data state
10. context menu
11. Reduced Motion
12. click 与 drag 行为验证

不要实现：

- Burn Rate
- 粒子
- 历史采样
- 趋势图
- Expanded UI 重构

完成后运行：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

然后实际启动应用，手动验证：

```text
hover
click
drag
right click
collapse/expand
restart restore
```

完成 Phase 2 后停止，不要自动进入 Phase 3。

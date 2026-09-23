# QuotaBar — Energy FX V4: Dense Particle Stream

目标仓库：`xzcode/quota-bar`

本轮只重做 **Compact Bar 的动态粒子视觉**。

核心方向：

> **取消“少量流星 / 拖尾”主视觉，改成密集、连续、严格水平流动的发光粒子流。**

目标体验：

```text
消耗慢  → 粒子少、速度慢
消耗快  → 粒子更密、速度更快
```

必须避免：

```text
一波一波出现
拖尾流星
上下乱串
随机换轨
跳跃
斜向飞行
```

---

## 1. 当前问题

当前版本主要问题：

1. 光点看起来是一波一波出现
2. 粒子数量太少，Bar 中经常出现大片空白
3. comet / streak / ribbon 混合后运动显得杂乱
4. 拖尾让视觉更像“流星”，而不是“持续能量流”
5. fast / veryFast 虽然有差异，但整体密度和速度仍不够明显

本轮不要继续优化 comet。

直接改成：

```text
Dense Particle Stream
```

---

## 2. 新视觉模型

Dynamic layer 只保留：

```text
Particle Stream
+
Soft Energy Glow
```

不再以：

```text
Comet
Long Trail
Random Ribbon
```

作为主要视觉。

粒子必须：

- 数量较多
- 连续不断
- 严格水平
- 分布均匀
- 速度随 activityLevel 提升
- 密度随 activityLevel 提升

---

## 3. Calm

保持现有省电策略：

```text
calm
→ 0 FPS
→ 无 DynamicEnergyLayer
→ 无粒子
→ 完全静态
```

不要修改。

---

## 4. 固定水平 Lane

当前 Compact Bar：

```text
210 × 32
```

建议使用 5 条固定 lane：

```text
lane 1 = y 6.5
lane 2 = y 11.5
lane 3 = y 16
lane 4 = y 20.5
lane 5 = y 25.5
```

所有粒子：

```text
固定 lane
严格水平
```

不要：

```text
sin wave
上下漂移
lane switching
```

允许最大纵向 jitter：

```text
±0.15 pt
```

如效果仍乱，完全禁用 jitter。

---

## 5. 粒子类型

只保留两类。

### Soft Particle

主数量来源：

```text
diameter: 0.8 ~ 1.8 pt
opacity: 0.12 ~ 0.38
```

颜色：

```text
cyan-blue
electric blue
violet
```

### Bright Particle

少量高亮核心：

```text
diameter: 2.2 ~ 3.2 pt
halo: core + 3 ~ 5 pt
opacity: 0.75 ~ 1.0
```

颜色：

```text
pale cyan
white-blue
light violet
```

Bright Particle 可以有轻微 halo，但不要长拖尾。

---

## 6. 不要拖尾

明确移除：

```text
comet long trail
long streak tail
gradient comet tail
```

允许：

```text
非常轻微横向 blur
```

模拟 motion blur，但不能形成明显流星尾巴。

---

## 7. 粒子密度

### Active

```text
总粒子：12 ~ 18
Bright：2 ~ 3
```

### Fast

```text
总粒子：24 ~ 32
Bright：4 ~ 6
```

### VeryFast

```text
总粒子：38 ~ 52
Bright：6 ~ 9
```

VeryFast 时 Bar 内必须持续存在大量流动光点，不能再出现明显大片空白。

---

## 8. 粒子分布必须均匀

不要：

```text
一组粒子一起进入
一组粒子一起离开
```

初始化时应让 phase 均匀分布在 `[0, 1)`。

优先使用：

```text
stratified distribution
```

例如：

```text
particle 0 → phase 0.03
particle 1 → phase 0.08
particle 2 → phase 0.13
...
```

再加少量固定 seed offset。

目标：

```text
任何时刻整条 Bar 都有粒子
```

---

## 9. 消除“一波一波”

每个粒子拥有固定参数：

```text
id
lane
phaseOffset
speedMultiplier
size
opacity
colorVariant
isBright
```

这些参数只在初始化时确定。

运行期间禁止重新随机。

位置只由：

```text
elapsed
+
phaseOffset
+
speedMultiplier
```

连续计算。

禁止每轮重新生成整组粒子。

---

## 10. Wrap 逻辑

粒子从左侧离开后，单独 wrap 到右侧。

不能整批 reset。

建议可视区外完成循环：

```text
right edge = width + 6
left edge = -6
```

Wrap 不能在画面中央产生跳跃。

---

## 11. 速度

### Active

```text
travel time: 4.0 ~ 5.0 s
```

### Fast

```text
travel time: 1.8 ~ 2.6 s
```

### VeryFast

```text
travel time: 0.9 ~ 1.5 s
```

VeryFast 必须明显有高速数据流感。

---

## 12. Speed Variation

速度差异控制在：

```text
±8% ~ 12%
```

不要出现大幅速度差，否则会重新显得杂乱。

目标是：

```text
多条同向高速车流
```

而不是每个粒子各飞各的。

---

## 13. 方向

统一：

```text
right → left
```

所有粒子同向。

禁止：

```text
反向粒子
斜向粒子
```

---

## 14. Ribbon / Comet 降级

V4 中：

```text
EnergyRibbonView 不再作为主要动态效果
```

可以完全停用动态 Ribbon。

也可以只保留极淡、模糊、低透明的 Soft Energy Glow。

视觉主体必须是：

```text
Dense Particle Stream
```

---

## 15. Soft Energy Glow

为了避免纯粒子看起来太“点状”，动态时允许有一层非常轻的蓝紫背景光带：

```text
宽 60 ~ 100 pt
opacity 0.04 ~ 0.10
```

它只能作为氛围层。

不能出现清晰 ribbon 边界。

---

## 16. Text Safe Zone

中央文字：

```text
89% · 62%
```

必须始终最清楚。

中央大致：

```text
x = 55 ~ 155 pt
```

粒子经过时 opacity 乘：

```text
0.45 ~ 0.65
```

Bright Particle 在文字核心区域进一步降亮度。

不要完全切断粒子流。

---

## 17. 粒子颜色

Normal：

Soft：

```text
#55BFFF
#557BFF
#7B5BFF
```

Bright：

```text
#C8F4FF
#D6E6FF
#E1D4FF
```

不要全部使用纯白。

Low / Critical 继续根据 danger state 调整色相。

---

## 18. Active 目标

```text
12~18 粒子
较慢
低密度
持续流动
```

感觉：

```text
Codex 正在工作
```

---

## 19. Fast 目标

```text
24~32 粒子
明显更快
明显更密
```

感觉：

```text
持续高速工作
```

任意时刻 Bar 内都应有较多粒子。

---

## 20. VeryFast 目标

```text
38~52 粒子
0.9~1.5s 穿过 Bar
6~9 Bright Particle
```

感觉：

```text
高吞吐 Token 流
```

必须明显比 fast 更快、更密，但不能闪烁。

---

## 21. 不得出现批次感

如果用户能明显感觉：

```text
一批粒子来了
→ 中间空了
→ 下一批又来了
```

则实现失败。

正确效果：

```text
连续
均匀
稳定
不断
```

---

## 22. FPS 保持

继续：

```text
calm     0 FPS
active   12 FPS
fast     18 FPS
veryFast 24 FPS
```

速度只通过 travel time 控制。

不要通过提高 FPS 获得速度感。

---

## 23. 性能实现

VeryFast 即使 52 个粒子，也应使用：

```text
一个 Canvas
一个 TimelineView
```

统一绘制。

不要：

```text
每个粒子一个 SwiftUI View
```

---

## 24. 粒子参数缓存

建议预生成：

```swift
struct ParticleDescriptor {
    let phase: Double
    let lane: Int
    let speedMultiplier: Double
    let size: Double
    let opacity: Double
    let colorIndex: Int
    let isBright: Bool
}
```

不要每帧创建随机数据。

activityLevel 变化时才调整 descriptor 集合。

---

## 25. Activity Level 切换

例如：

```text
active → fast
fast → veryFast
```

不要整批粒子突然 reset。

建议：

- 保持已有粒子的 phase seed
- 新增粒子渐入
- 多余粒子渐出
- 过渡 0.2 ~ 0.4 秒

如果实现复杂，优先保证“不 reset 位置”。

---

## 26. Calm 切换

进入 calm：

```text
DynamicEnergyLayer fade out 0.2s
→ TimelineView 卸载
→ 0 FPS
```

不要生硬瞬间消失。

---

## 27. Demo Mode

继续保留 DEBUG Demo：

```text
calm
active
fast
veryFast
```

V4 必须使用 Demo Mode 调试。

---

## 28. 建议代码结构

建议把现有 ParticleFlowView 重写为：

```text
DenseParticleStreamView
```

最终动态结构：

```text
DynamicEnergyLayer
├── SoftEnergyGlow
└── DenseParticleStream
```

尽量简化旧的：

```text
Ribbon
Comet
Trail
Streak
```

体系。

---

## 29. 可以停用 / 删除

如果不再使用，可以停用或删除：

```text
CometTrail
long streak
wave Ribbon
Edge Energy Streak
```

不要留下大量死代码。

---

## 30. 视觉验收

Active：

```text
持续有光点经过
但整体安静
```

Fast：

```text
明显更密
明显更快
连续无空档
```

VeryFast：

```text
整根 Bar 内部像高速数据流
大量细小光点持续水平穿过
```

---

## 31. 必须录屏

完成后提供：

```text
active 8 秒
fast 8 秒
veryFast 8 秒
```

8 秒用于验证：

```text
是否还有一波一波
是否存在周期性空档
是否始终连续
```

---

## 32. 本轮禁止修改

禁止修改：

```text
LocalTokenUsageMonitor
今日 Token 统计
TokenActivityPolicy 阈值
QuotaDangerState
Expanded UI
Compact 尺寸
app-server
JSON-RPC
```

---

## 33. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 34. 最终汇报

完成后停止开发，并汇报：

```text
1. 是否移除 comet / long trail
2. active / fast / veryFast 粒子数量
3. Bright Particle 数量
4. travel time
5. lane 数量
6. phase 如何均匀分布
7. wrap 如何实现
8. 如何避免批次感
9. activityLevel 切换是否会 reset
10. FPS
11. build / tests / diff check
12. active / fast / veryFast 8 秒录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_ENERGY_FX_V4.md` 并严格执行。

本轮彻底停止继续优化 comet / 流星拖尾方案。

新的核心视觉：

```text
密集
连续
水平
稳定
发光粒子流
```

必须做到：

```text
消耗越快 → 粒子越密
消耗越快 → 粒子越快
```

重点消除：

```text
一波一波出现
大片空白
拖尾流星
上下乱串
跳跃
```

完成后必须提供 active / fast / veryFast 各 8 秒录屏验证连续性。

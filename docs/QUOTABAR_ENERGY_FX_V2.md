# QuotaBar — Energy FX V2

目标仓库：`xzcode/quota-bar`  
当前实现基线：`53044292180a605f657c055434a464f8fd5507ab`

本轮只重做 **Compact Bar 的动态视觉效果**。

不要修改：

- LocalTokenUsageMonitor
- 今日 Token 统计
- TokenActivityLevel 判定阈值
- app-server / JSON-RPC
- 额度解析
- 5 小时 / 周额度
- Expanded 布局
- 210 × 32 尺寸
- calm = 0 FPS 的原则

---

## 1. 当前效果为什么“不够酷”

当前代码并不是没有做特效，而是特效视觉强度过低，而且主要动态元素刚好被文字挡住。

### 1.1 Ribbon 在文字正后方

当前 `EnergyRibbonView`：

```text
1 条时 centerY = 50%
2 条时 centerY = 35% / 65%
```

而文字：

```text
92% · 62%
```

正好占据 Bar 中央区域。

因此最有价值的动态视觉大量被文字覆盖。

---

### 1.2 Energy particle 也集中在中央

当前：

```swift
y = height * (0.48 + 0.08 * wave)
```

基本都在 Bar 中央。

结果：

```text
亮粒子
Comet
Ribbon
```

与文字重叠。

截图中最终只能明显看到文字左右两边的几个白点。

---

### 1.3 粒子太小

当前亮粒子直径：

```text
active 2.2 pt
fast 2.6 pt
veryFast 3.0 pt
```

在 `210 × 32` 的 Bar 里视觉存在感不足。

背景粒子更小：

```text
约 0.9 ~ 1.7 pt
```

所以整体更像“几个白点”，不像能量流。

---

### 1.4 Fast 的 Comet 太短

当前：

```text
fast trail = 7 pt
veryFast trail = 12 pt
```

在 210pt 宽 Bar 里非常短。

视觉上更像小短线，而不是高速粒子。

---

### 1.5 Ribbon opacity 太低

当前 fast ribbon：

```text
opacity ≈ 0.25
```

加上 blur 后更加不明显。

---

## 2. V2 视觉目标

目标不是“多加白点”。

目标应该变成：

```text
静止：
一颗安静的蓝紫能量胶囊

活跃：
胶囊内部开始有电流 / 等离子体流动

较快：
明显看到两条能量流 + 带拖尾的高速核心

很快：
能量流密度和速度明显增加，但仍然精致
```

关键词：

```text
Plasma
Energy Stream
Aurora
Comet
Electric Blue
Violet
```

不要做成：

```text
雪花
星空
烟花
游戏技能爆炸
```

---

## 3. 保留中央文字安全区

动态视觉不要再把主要信息放在文字正后方。

对于 210 × 32：

建议把中心区域定义为：

```text
x = 55 ~ 155 pt
y = 8 ~ 24 pt
```

作为 text safe zone。

动态效果仍可经过，但 opacity 应降低。

主要 Ribbon / Comet 应优先走：

```text
上轨道：y ≈ 8 ~ 11
下轨道：y ≈ 21 ~ 24
```

形成：

```text
────── energy stream ──────
        92% · 62%
────── energy stream ──────
```

而不是：

```text
──── 92% · 62% ────
```

---

## 4. DynamicEnergyLayer V2

建议视觉分为四层：

```text
DynamicEnergyLayer
├── AuroraStreamLayer
├── CometLayer
├── SparkLayer
└── SweepLightLayer
```

全部由现有单一 `TimelineView` 驱动。

不能新增第二个 animation clock。

---

## 5. AuroraStreamLayer

取代当前过于细弱的 Ribbon 视觉。

不是普通 1px 曲线，而是“有宽度的柔和能量带”。

建议两层绘制：

```text
外层：
6 ~ 10 pt blur glow

内层：
1.5 ~ 2.5 pt bright core
```

颜色 normal 状态建议：

```text
cyan-blue
→ electric blue
→ violet
```

不要纯白 Ribbon。

---

## 6. Aurora Stream 轨道

### Active

```text
1 条
走上轨道或下轨道
轻微正弦波
```

### Fast

```text
2 条
一上一下
不同 phase / speed
```

### VeryFast

```text
2 条主流
+
允许 1 条非常淡的 secondary wake
```

主流数量仍不要过多。

---

## 7. Ribbon 推荐强度

### Active

```text
core opacity: 0.28
glow opacity: 0.15
length: 70 ~ 90 pt
```

### Fast

```text
core opacity: 0.42
glow opacity: 0.22
length: 95 ~ 120 pt
```

### VeryFast

```text
core opacity: 0.55
glow opacity: 0.30
length: 120 ~ 150 pt
```

不要整条 Bar 都亮。

---

## 8. Comet Layer

这是 V2 最明显的动态元素。

不要再使用“短线 + 白点”。

每个 comet：

```text
bright core
+
colored halo
+
long gradient tail
```

颜色：

```text
core: white / pale cyan
halo: electric blue / violet
tail: cyan-blue → violet → transparent
```

---

## 9. Comet 数量

```text
active: 1
fast: 2
veryFast: 3
```

不是所有 comet 同时出现。

通过不同 phase 让它们自然错开。

---

## 10. Comet 大小

建议：

```text
active core: 2.8 pt
fast core: 3.2 pt
veryFast core: 3.4 ~ 3.8 pt
```

halo：

```text
core + 4 ~ 7 pt
```

不要太大。

---

## 11. Comet Trail 长度

当前 7 / 12pt 太短。

改为：

```text
active: 8 ~ 12 pt
fast: 18 ~ 26 pt
veryFast: 28 ~ 42 pt
```

尾部必须：

```text
渐隐
略微 blur
```

不能是硬线条。

---

## 12. Comet 轨道

不要所有 comet 都走正中间。

建议：

```text
comet A → y 30%
comet B → y 70%
comet C → y 45%
```

并有：

```text
±1.5 ~ 2.5 pt
```

的轻微波动。

中心 comet 在经过文字安全区时降低 opacity。

---

## 13. Spark Layer

背景粒子不要再作为主特效。

它们只负责细节。

建议：

```text
active: 3 ~ 4
fast: 5 ~ 7
veryFast: 7 ~ 9
```

尺寸：

```text
1.0 ~ 2.0 pt
```

透明度：

```text
0.15 ~ 0.45
```

不要统一白色。

部分使用：

```text
pale blue
pale violet
```

---

## 14. Sweep Light

保留 Moving Highlight，但当前视觉存在感不足。

改成：

```text
宽 32 ~ 52 pt
斜向柔光
```

不要做白色矩形。

可以使用：

```text
透明 → 蓝白 → 紫白 → 透明
```

并轻微倾斜，例如：

```text
10° ~ 18°
```

### Active

很弱。

### Fast

明显可感知。

### VeryFast

速度更快、亮度稍高。

---

## 15. 增加 Edge Energy Streak

新增一个非常克制的顶部边缘流光。

表现：

```text
一小段 20 ~ 40 pt 的亮边
沿 Bar 顶部移动
```

颜色：

```text
cyan → transparent
```

Fast / VeryFast 才启用。

作用：

即使内部流光被文字部分遮挡，用户仍然能明显感知“正在高速工作”。

不要绕完整边框跑一圈。

---

## 16. Blend Mode

动态发光层可以尝试：

```swift
.blendMode(.plusLighter)
```

或 Canvas 对应 additive / screen 风格 blend。

但必须：

- 只用于 DynamicEnergyLayer
- 不影响文字
- 不导致整根 Bar 泛白

如果实际效果过曝，退回普通 alpha compositing。

---

## 17. 动态颜色不要只有白色

当前视觉像白点的原因之一是：

```text
particle core ≈ white
trail ≈ white
ribbon ≈ palette + white
```

V2 应让能量本身带颜色。

Normal 状态动态色建议：

```text
#67D8FF  cyan
#5B78FF  electric blue
#9B6BFF  violet
```

白色只作为最亮 core，占比很少。

---

## 18. Danger Color 仍保持独立

不要改 quota danger 规则。

### Normal

动态：

```text
cyan / electric blue / violet
```

### Low

动态：

```text
violet / warm purple / amber accent
```

### Critical

动态：

```text
magenta / red-violet
```

Activity 决定速度与强度。

Quota 决定色相。

---

## 19. 文字层必须永远最清楚

Text 始终位于 DynamicEnergyLayer 上方。

可以增加：

```text
black shadow opacity 0.25
radius 2 ~ 3
```

如果 fast / veryFast 太亮，可在文字背后增加非常淡的局部 dark vignette：

```text
宽约 100 pt
opacity 0.06 ~ 0.10
```

不要做明显文字底板。

---

## 20. Fast 必须有明显视觉差异

用户截图当前状态：

```text
较快
```

但 Compact 看起来只是几个点。

V2 验收：

当 Expanded 显示：

```text
较快
```

Compact 必须一眼能看到：

```text
两条能量流
+
至少一个明显 comet
+
短到中等长度拖尾
+
移动柔光
```

无需盯着看几秒才发现。

---

## 21. VeryFast 必须更明显

VeryFast：

```text
能量流速度提高
comet 数量 3
trail 更长
edge streak
sweep 更明显
```

但仍然：

```text
不闪烁
不 pulsate 整个 Bar
不震动
不缩放
```

---

## 22. Calm 不变

Calm 必须继续：

```text
0 FPS
无粒子
无 TimelineView
只有 StaticEnergyBackground
```

不能为了酷炫破坏省电设计。

---

## 23. FPS 不变

继续：

```text
active = 12 FPS
fast = 18 FPS
veryFast = 24 FPS
```

不要增加到 30 / 60 FPS。

“更酷”靠视觉设计，不靠暴力提高帧率。

---

## 24. 性能限制

动态层：

```text
总 spark + comet 数量 <= 12
Aurora stream <= 2 主流
VeryFast secondary wake <= 1
```

不要引入：

```text
Metal
SpriteKit
第三方粒子库
shader dependency
```

继续 SwiftUI Canvas 即可。

---

## 25. 需要修改的主要文件

重点：

```text
DynamicEnergyLayer.swift
EnergyRibbonView.swift
ParticleFlowView.swift
```

可以新增：

```text
AuroraStreamView.swift
CometFlowView.swift
```

但不要拆出大量小组件。

`StaticEnergyBackground` 不需要大改。

---

## 26. 建议实现顺序

### Step 1

先修轨道：

```text
主动态视觉从中央移到上下两条 lane
```

### Step 2

重做 Ribbon 为 Aurora Stream。

### Step 3

把 comet trail 从 7 / 12pt 升级为真正渐变长尾。

### Step 4

粒子颜色从“白点”为主改成 cyan / blue / violet。

### Step 5

增强 Sweep Light。

### Step 6

Fast / VeryFast 增加 Edge Energy Streak。

---

## 27. 必须提供 Demo Mode

为了视觉验收，建议 Debug build 增加临时预览方式：

```text
calm
active
fast
veryFast
```

可以通过 SwiftUI Preview、DEBUG context menu 或内部 debug flag。

不要让测试人员必须真的烧到 500K tokens/min 才能看 VeryFast。

该 Demo Mode：

```text
只在 DEBUG
不进入 Release UI
不影响真实 activity
```

---

## 28. 截图 / 录屏验收

静态截图无法完全验收动态效果。

完成后请提供：

```text
calm 截图
active 录屏
fast 录屏
veryFast 录屏
```

重点录 Compact Bar。

---

## 29. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 30. 最终汇报

完成后停止开发并汇报：

```text
1. Ribbon 为什么比旧版更明显
2. text safe zone 如何处理
3. comet 数量 / 尺寸 / trail 长度
4. spark 数量
5. sweep light 参数
6. edge streak 如何实现
7. dynamic palette
8. active / fast / veryFast 的具体差异
9. FPS
10. build / tests / diff check
11. active / fast / veryFast 录屏
```

---

## 给 Codex 的执行指令

阅读 `QUOTABAR_ENERGY_FX_V2.md` 并严格执行。

当前问题不是 Token 数据，而是动态视觉太弱。

基于最新代码，重点修复：

```text
Ribbon 和粒子主要位于 Bar 正中央，被 “92% · 62%” 文字遮挡
Fast comet trail 只有约 7pt
particle 太小
Ribbon opacity 太低
动态颜色过度依赖白色
```

目标：

```text
从“小白点移动”
升级成
“Aurora Energy Stream + Colored Comet + Sweep Light”
```

保持：

```text
calm 0 FPS
active 12 FPS
fast 18 FPS
veryFast 24 FPS
```

不要修改 Token 统计与业务逻辑。

完成后提供 active / fast / veryFast 的录屏用于视觉验收。

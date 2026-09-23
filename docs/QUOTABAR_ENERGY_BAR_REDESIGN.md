# QuotaBar — Compact Energy Bar Redesign

目标仓库：`xzcode/quota-bar`  
当前实现基线：`ba1126165a47f4935eca1fba0484737f91a6bc8f`

本轮只重做 **Collapsed / Compact Bar 的视觉层与动画层**。

不要修改：

- Codex app-server 协议
- JSON-RPC transport
- 额度解析
- 5 小时 / 周额度逻辑
- Burn Rate 阈值
- Reserve fallback
- Expanded 卡片整体布局
- 窗口展开 / 收起业务逻辑
- UserDefaults 兼容逻辑

---

## 1. 当前问题

当前收纳态约为：

```text
240 × 28
```

实际视觉问题：

1. 仍然偏长、偏扁
2. calm 状态虽然不动，但仍显示静态白点
3. 正常额度下颜色会随着 remainingPercent 在 25% ~ 100% 区间连续插值
4. 64% 左右时容易出现偏粉紫 / 灰紫
5. 粒子动态本质仍是“小白点移动”
6. 缺少统一的“能量胶囊”视觉语言
7. 静态状态质感不足

---

## 2. 新设计目标

Compact Bar 应该像：

```text
一颗安静的能量胶囊
```

静止时：

```text
安静
有质感
无粒子
无动画
有内发光
有冷色能量感
```

动态时：

```text
出现能量流
少量高亮粒子
短拖尾
轻微流光
```

不要做成游戏血条、霓虹灯牌、星空、雪花、烟花或高速闪烁特效。

---

## 3. 新尺寸

Collapsed 改为：

```text
210 × 32
```

即：

```swift
width = 210
height = 32
cornerRadius = 16
```

目标：

```text
更短
更厚
更像胶囊
```

如果实际运行后仍显得偏长，可允许进一步调整为：

```text
200 × 32
```

默认先使用 `210 × 32`。

Expanded 尺寸保持不变。

---

## 4. 文本

继续显示：

```text
100% · 64%
```

不要改成单百分比。

建议字体：

```swift
.font(.system(size: 13, weight: .semibold, design: .rounded))
.monospacedDigit()
```

文本居中、白色、轻微阴影。

---

## 5. Normal 状态颜色策略必须重做

当前代码在：

```text
remaining 25% ~ 100%
```

之间做 palette 插值。

这会导致：

```text
64%
```

出现偏粉紫 / 灰紫。

本轮不要继续这么做。

---

## 6. Normal 状态固定冷色

当：

```text
remaining > 25%
```

时整个 normal 区间统一使用固定冷色系。

建议：

```text
左：Electric Blue
中：Indigo
右：Violet
```

建议颜色：

```text
#2D5BFF
#4B45D6
#6B3EC7
```

正常状态下：

```text
100%
80%
64%
30%
```

只要仍然 >25%，主色调都保持一致。

不要因为 remaining 改变 hue。

---

## 7. Low 状态

当：

```text
11% ~ 25%
```

才开始出现暖色。

建议：

```text
Indigo → Violet → Warm Purple → 少量 Amber
```

不要整个 Bar 变橙。

---

## 8. Critical 状态

当：

```text
<= 10%
```

使用：

```text
Deep Violet → Magenta Red
```

允许更强视觉警告，但仍然不要闪烁。

---

## 9. StaticEnergyBackground

新增一个独立静态背景组件：

```text
StaticEnergyBackground
```

它必须在 calm 时独立完成完整视觉。

组成：

```text
Base Gradient
+
Left Glow
+
Right Glow
+
Center Inner Glow
+
Top Highlight
+
Border Glow
```

---

## 10. Base Gradient

normal：

```text
蓝 → 靛蓝 → 紫
```

建议使用 3 个 stop。

不要使用完全均匀、死板的横向 LinearGradient。

可以使用：

```text
LinearGradient + radial overlays
```

但不要引入 shader。

---

## 11. Left Glow

左侧增加一个非常柔和的蓝色 radial glow：

```text
opacity：0.20 ~ 0.35
blur：12 ~ 20
```

不要有明确圆形边缘。

---

## 12. Right Glow

右侧增加紫色 radial glow：

```text
opacity：0.16 ~ 0.30
blur：12 ~ 20
```

---

## 13. Center Inner Glow

中心区域增加非常轻的内部亮度：

```text
中间略亮
两边略暗
```

目标：像能量被封装在玻璃胶囊内部。

---

## 14. Top Highlight

顶部增加一条很细的玻璃高光：

```text
height: 1 ~ 2 pt
opacity: 0.10 ~ 0.20
```

仅在上半部分。

---

## 15. Border Glow

外边缘：

```text
1px
冷紫 / 蓝紫
低透明度
```

建议使用轻微双层 overlay，但不要太亮。

---

## 16. Calm 状态

当：

```swift
BurnRateLevel == .calm
```

或者：

```text
isParticlePulseActive == false
```

必须：

```text
不创建 TimelineView
不创建动态 Particle Canvas
不移动渐变
不显示静态白点
不播放任何持续动画
```

也就是说：

```text
0 FPS
```

视觉只由 `StaticEnergyBackground + Text` 构成。

---

## 17. 删除 calm 静态粒子

当前：

```swift
backgroundParticleCount(.calm) = 5
```

改为：

```swift
backgroundParticleCount(.calm) = 0
```

更推荐：calm 分支完全不创建 `ParticleFlowView`。

---

## 18. 动态层独立

新增：

```text
DynamicEnergyLayer
```

只有：

```text
active
fast
veryFast
```

才创建。

组成：

```text
Energy Ribbon
+
Background Flow Particles
+
Energy Particles
+
Comet Trails
+
Moving Highlight
```

---

## 19. Energy Ribbon

这是本轮最重要的新视觉。

不要只靠粒子。

增加一条非常淡的能量流带，沿统一方向移动。

建议用：

```text
Canvas
或 SwiftUI Path
```

画一条轻微弯曲、透明、蓝紫色、有 blur 的流线。

视觉更像：

```text
~~~~~~>
```

而不是普通直线。

---

## 20. Energy Ribbon 强度

active：

```text
1 条
非常淡
缓慢移动
```

fast：

```text
1 ~ 2 条
稍亮
有轻微层次
```

veryFast：

```text
最多 2 条
速度明显
亮度略提高
```

不要超过 2 条主流带。

---

## 21. Background Flow Particles

动态状态才显示。

建议：

```text
active: 5 ~ 7
fast: 7 ~ 9
veryFast: 8 ~ 10
```

特点：

```text
小
淡
慢于亮粒子
```

不要占主要视觉。

---

## 22. Energy Particles

亮粒子：

```text
active: 1
fast: 2
veryFast: 2
```

特点：

```text
更亮
稍大
有 halo
速度快
```

diameter 建议控制在：

```text
2 ~ 3.5 pt
```

---

## 23. Comet Trails

fast / veryFast 才启用。

建议：

```text
短拖尾
长度 5 ~ 14 pt
透明渐隐
```

不要再只是 3px 小椭圆。

建议真正画：

```text
bright core → short fade → transparent
```

---

## 24. Moving Highlight

动态状态增加一个柔和亮区 sweep。

不是整条白光。

应该像一个宽约：

```text
20 ~ 40 pt
```

的柔和亮区缓慢穿过 Bar。

- active：很弱
- fast：明显一点
- veryFast：更快，但仍柔和

---

## 25. 动画帧率

继续保持：

```text
calm: 0 FPS
active: 12 FPS
fast: 18 FPS
veryFast: 24 FPS
```

不要回到 30 / 60 FPS。

---

## 26. 单一动画时钟

动态状态必须只有一个 `TimelineView`。

统一驱动：

```text
Energy Ribbon
Particles
Comet Trails
Moving Highlight
Gradient motion
```

不要每个子组件各自创建 TimelineView。

---

## 27. 动效方向统一

当前粒子使用：

```text
right → left
```

可以继续保留。

但所有动态效果必须统一：

```text
Ribbon
Particles
Highlight
Comet
```

不要方向打架。

---

## 28. Burn Rate 视觉映射

不要修改 BurnRateCalculator 阈值。

只调整视觉。

### active

```text
轻微 Energy Ribbon
1 个亮粒子
无 comet 或极弱 comet
```

### fast

```text
明显 Ribbon
2 个亮粒子
短 Comet
Moving Highlight
```

### veryFast

```text
更明显 Ribbon
2 个亮粒子
更快 Comet
更强 Moving Highlight
```

---

## 29. Pulse 机制保持

当前：

```text
检测到 fresh usage increase
→ isParticlePulseActive = true
→ 30 秒后停止
```

这个机制可以保留。

不要改成只要 burnRate 非 calm 就永远播放。

---

## 30. 静态背景与 remaining 解耦

Normal 区间不要根据：

```text
64%
76%
100%
```

连续变色。

remaining 只影响：

```text
数字
Expanded progress
危险状态切换
```

而不是 normal hue。

---

## 31. Stale 状态

isStale 时：

```text
降低饱和度
保留橙色小提示点
```

不要把整个 palette 直接变成灰色。

---

## 32. Hover

hover 时：

```text
brightness +0.03 ~ +0.05
```

即可。

不要因为 hover 启动粒子。

calm + hover 仍然保持 0 FPS。

---

## 33. Shadow

当前 shadow 可以稍微克制：

```text
radius 6 ~ 8
y 3
```

避免 Bar 变厚后像一个悬浮按钮。

---

## 34. Reduced Motion

保持：

```text
所有动态层关闭
```

即使 active / fast / veryFast，也只显示静态背景。

---

## 35. 建议组件结构

```text
CompactQuotaBar
├── StaticEnergyBackground
├── DynamicEnergyLayer?   // only when active
├── QuotaText
└── StaleBadge
```

DynamicEnergyLayer：

```text
DynamicEnergyLayer
├── EnergyRibbon
├── ParticleLayer
├── CometTrailLayer
└── MovingHighlight
```

---

## 36. 文件建议

可新增：

```text
Sources/QuotaBar/Features/Quota/
  StaticEnergyBackground.swift
  DynamicEnergyLayer.swift
  EnergyRibbonView.swift
```

可以继续复用：

```text
ParticleFlowView.swift
QuotaVisualStyle.swift
```

不要拆太碎。

---

## 37. QuotaVisualStyle 重构

建议把：

```swift
gradientColors(remaining:)
```

改为更明确的：

```swift
palette(for state:)
```

例如：

```swift
enum QuotaDangerState {
    case normal
    case low
    case critical
    case unknown
}
```

避免 normal 区间继续按 remainingPercent 连续插值。

---

## 38. Low / Critical 可以保留插值

只在：

```text
0 ~ 25%
```

内允许颜色随着额度变化。

normal 固定 palette。

---

## 39. 视觉验收

实际测试：

```text
100% · 64%
100% · 25%
100% · 10%
```

重点：

```text
64% 不应再出现灰粉紫
```

normal 应稳定呈现：

```text
蓝
靛蓝
紫
```

---

## 40. Calm 验收

calm 状态必须：

```text
无粒子
无 Ribbon
无 sweep
无 TimelineView
无持续动画
```

但视觉仍应有：

```text
深度
高光
静态内发光
```

---

## 41. Active 验收

active 时能看出“开始活动”，但不能抢眼。

---

## 42. Fast 验收

fast 时明显有能量流，至少应能看到：

```text
Ribbon
亮粒子
短拖尾
```

---

## 43. VeryFast 验收

veryFast 明显比 fast 更活跃，但：

```text
不能闪烁
不能刺眼
不能像游戏技能
```

---

## 44. 性能验收

calm：

```text
Activity Monitor 中 CPU / Energy Impact 应显著低于动态状态
```

active / fast / veryFast 仍需保持低资源占用。

---

## 45. 不允许修改

本轮禁止：

```text
app-server
JSON-RPC
rate limit parser
burn rate thresholds
reserve logic
expanded quota layout
menu bar behavior
window persistence
refresh scheduler
```

---

## 46. 实现顺序

### Step 1

尺寸：

```text
240 × 28 → 210 × 32
```

### Step 2

重做 normal palette：

```text
固定蓝 → 靛蓝 → 紫
```

去掉 25 ~ 100 连续 hue 插值。

### Step 3

实现：

```text
StaticEnergyBackground
```

先确保 calm 完全静态也足够漂亮。

### Step 4

calm：

```text
完全移除粒子
```

### Step 5

实现：

```text
DynamicEnergyLayer
```

### Step 6

加入：

```text
Energy Ribbon
Moving Highlight
Comet Trails
```

### Step 7

active / fast / veryFast 做视觉差异。

---

## 47. Build / Tests

完成后运行：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

实际运行：

```bash
swift run QuotaBar
```

---

## 48. 最终汇报

完成后停止开发。

请汇报：

```text
1. collapsed 最终尺寸
2. normal palette 最终颜色
3. calm 是否彻底没有 TimelineView
4. calm 是否完全没有粒子
5. StaticEnergyBackground 由哪些层组成
6. Energy Ribbon 怎么实现
7. Comet Trail 怎么实现
8. Moving Highlight 怎么实现
9. active / fast / veryFast 的视觉差异
10. animation FPS
11. build 结果
12. tests 结果
13. git diff --check 结果
14. calm / active / fast / veryFast 的截图
```

---

## 49. 给 Codex 的执行指令

阅读 `QUOTABAR_ENERGY_BAR_REDESIGN.md` 并严格执行。

本轮只重做 Compact / Collapsed Bar 的视觉层。

核心要求：

```text
210 × 32
normal 固定蓝紫冷色
calm 0 粒子 / 0 FPS
静态状态靠 glow + highlight 做质感
动态状态加入 Energy Ribbon + Comet Trails + Moving Highlight
active / fast / veryFast 才播放动态效果
```

不要修改业务逻辑和 Codex 数据链路。

完成后运行 build / tests / diff check，并停止开发，等待视觉验收。

# QuotaBar — Sparkle & Purple Activity Tuning

目标仓库：`xzcode/quota-bar`  
当前实现基线：`c19e9add71965aee89054cc866030afe3fee09b0`

本轮只做两项视觉增强：

1. 右侧紫色区域随着 Token 活动速度提升而略微增强
2. Dense Particle Stream 增加“星光闪烁”感

不要修改：

- LocalTokenUsageMonitor
- token_count 解析
- 今日 Token 统计
- TokenActivityPolicy 阈值
- app-server / JSON-RPC
- QuotaDangerState 规则
- Expanded UI
- Compact Bar 尺寸
- calm = 0 FPS 的原则

---

## 1. 目标视觉

希望 Compact Bar 在不同 activityLevel 下表现为：

```text
slow
→ 蓝紫能量条
→ 少量轻微星光

medium
→ 右侧紫色稍增强
→ 星光感更明显

fast
→ 右侧紫色进一步增强
→ 高频但克制的局部 sparkle

veryFast
→ 右侧紫色最明显
→ 高速粒子流中持续出现亮点闪烁
```

整体仍应保持：

```text
高级
干净
克制
连续
```

不要做成：

```text
霓虹灯
满屏乱闪
游戏技能
整条 Bar 同步呼吸
```

---

## 2. 右侧紫色区域增强

当前 normal palette 仍保持：

```text
blue → indigo → violet
```

不要修改 quota danger color 规则。

activityLevel 只对 Compact Bar 右侧约：

```text
25% ~ 35%
```

区域做轻微紫色增强。

---

## 3. 建议新增 Activity Accent 强度

建议集中定义：

```swift
extension TokenActivityLevel {
    var rightVioletAccent: Double {
        switch self {
        case .calm: return 0.00
        case .slow: return 0.05
        case .medium: return 0.10
        case .fast: return 0.18
        case .veryFast: return 0.28
        }
    }
}
```

这些值是初始视觉参数，可按实际效果微调。

---

## 4. 紫色增强方式

优先通过：

```text
Right Radial Glow
+
Violet Overlay
```

实现。

不要直接重写整条 base gradient。

例如在 Compact 动态背景中增加：

```text
右侧 purple radial glow
center x ≈ 0.85 ~ 1.0
opacity = activityLevel.rightVioletAccent
blur = 12 ~ 20
```

VeryFast 时：

```text
右侧更偏 violet / electric purple
```

但不能明显变成：

```text
pink
magenta
```

除非 quota danger state 本身已经是 low / critical。

---

## 5. Danger State 与 Activity 必须分离

Quota danger：

```text
normal / low / critical
```

继续决定主要色相。

Token activity：

```text
calm / slow / medium / fast / veryFast
```

只决定：

```text
右侧紫色 accent
粒子速度
粒子密度
sparkle 强度
```

不能让：

```text
veryFast + 额度正常
```

直接变成危险红色。

---

## 6. 星光闪烁设计原则

不要让所有粒子一起闪。

Sparkle 应该表现为：

> 一部分 Bright Particle 在高速流动过程中偶尔“catch light”，短暂变亮。

也就是说：

```text
运动仍然连续
亮度连续变化
每个粒子相位不同
```

不要：

```text
每帧随机 opacity
突然 0 → 1
全部同步闪
整根 Bar pulse
```

---

## 7. 粒子分类

继续保持 Dense Particle Stream 两类：

```text
Soft Particle
Bright Particle
```

### Soft Particle

主要负责：

```text
密度
速度感
持续流动
```

只允许非常轻微 shimmer。

### Bright Particle

主要负责：

```text
sparkle
halo
星光感
```

Sparkle 只重点作用于 Bright Particle。

---

## 8. Bright Particle 固定 Twinkle 参数

建议在 `ParticleDescriptor` 中增加：

```swift
let twinklePhase: Double
let twinkleSpeed: Double
let twinkleDepth: Double
let sparkleEnabled: Bool
```

这些参数：

```text
初始化时确定
运行中不重新随机
```

确保动画连续稳定。

---

## 9. Twinkle 函数

建议使用连续函数，例如：

```swift
let wave = 0.5 + 0.5 * sin(time * speed + phase)
let twinkle = 1.0 - depth + wave * depth
```

然后作用于：

```text
core opacity
halo opacity
halo size
```

不要对 position 做闪烁处理。

---

## 10. Slow

建议：

```text
sparkle-enabled bright particle 比例：
10% ~ 20%

twinkle frequency：
0.8 ~ 1.2 Hz

twinkle depth：
0.10 ~ 0.18
```

视觉应是：

```text
偶尔有一点亮光
```

而不是“在闪”。

---

## 11. Medium

建议：

```text
sparkle ratio：
20% ~ 30%

frequency：
1.2 ~ 1.8 Hz

depth：
0.15 ~ 0.24
```

视觉：

```text
开始明显有星光感
```

---

## 12. Fast

建议：

```text
sparkle ratio：
30% ~ 45%

frequency：
1.8 ~ 2.6 Hz

depth：
0.20 ~ 0.32
```

视觉：

```text
高速粒子流中不断有亮点出现
```

但不能乱闪。

---

## 13. VeryFast

建议：

```text
sparkle ratio：
45% ~ 60%

frequency：
2.4 ~ 3.4 Hz

depth：
0.25 ~ 0.38
```

视觉：

```text
高密度高速数据流
+
持续局部星光闪烁
```

但仍然：

```text
不同粒子不同步
不全局闪烁
不刺眼
```

---

## 14. Soft Particle Shimmer

Soft Particle 可以有非常轻微亮度变化：

```text
opacity multiplier:
0.92 ~ 1.08
```

频率更慢：

```text
0.3 ~ 0.8 Hz
```

如果实际效果让画面变乱：

```text
直接关闭 Soft Particle shimmer
```

优先保证干净。

---

## 15. Sparkle Halo

Bright Particle 在 twinkle 峰值时可以让 halo：

```text
略亮
略大
```

例如：

```text
haloOpacity *= 0.8 + 0.4 * twinkle
haloRadius *= 0.95 + 0.10 * twinkle
```

变化必须很小。

不要出现：

```text
突然爆出大光圈
```

---

## 16. Sparkle Core

Core 亮度建议：

```text
base opacity × twinkleMultiplier
```

不要改变粒子位置。

不要增加额外 View。

仍然在同一个 Canvas 中完成。

---

## 17. Text Safe Zone

中央百分比：

```text
92% · 58%
```

必须保持最清楚。

如果 Bright Particle 进入中央文字区域：

```text
sparkle intensity × 0.45 ~ 0.60
```

Soft Particle：

```text
opacity × 0.55 ~ 0.70
```

不要让亮点刚好在数字笔画后爆亮。

---

## 18. 右侧紫色与 Sparkle 联动

activityLevel 提升时：

```text
右侧更紫
+
sparkle 更频繁
+
粒子更密、更快
```

这三个变化应该共同形成：

```text
活动越强 → 能量越活跃
```

但每个变化都应该是渐进的。

---

## 19. 性能要求

本轮不要增加粒子数量。

只在现有粒子上增加：

```text
少量 sin / phase 数学计算
```

不要增加：

```text
额外 TimelineView
额外粒子层
额外 Canvas
新的刷新机制
```

Sparkle 必须由现有动画时钟驱动。

---

## 20. Calm

保持：

```text
0 FPS
无 DynamicEnergyLayer
无 sparkle
无活动紫色 accent
```

只显示静态能量胶囊。

---

## 21. Reduced Motion

开启系统 Reduced Motion 时：

```text
关闭 sparkle
关闭动态 right violet accent
保持静态背景
```

Token 数据仍正常显示。

---

## 22. DEBUG Demo

继续使用现有：

```text
slow
medium
fast
veryFast
```

Demo Mode。

本轮必须分别录制四档效果。

---

## 23. 视觉验收

### Slow

```text
右侧轻微偏紫
偶尔有亮点
整体安静
```

### Medium

```text
紫色稍明显
星光感开始可见
```

### Fast

```text
右侧明显更有紫色能量
亮点频率明显提高
```

### VeryFast

```text
右侧紫色最强
高密度粒子流中不断出现星光闪烁
```

但不能：

```text
全局闪
同步闪
高频抖动
```

---

## 24. 推荐修改文件

重点：

```text
DenseParticleStreamView.swift
TokenActivityEnergyStyle.swift
DynamicEnergyLayer.swift
SoftEnergyGlow.swift
```

如需要，可以让 `StaticEnergyBackground` 接收 activity accent，但不要重构业务逻辑。

---

## 25. 本轮不要修改

禁止：

```text
LocalTokenUsageMonitor
今日 Token
TokenActivityPolicy threshold
Quota danger threshold
Expanded UI
Compact 尺寸
app-server
JSON-RPC
```

---

## 26. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 27. 最终汇报

完成后停止开发，并汇报：

```text
1. right violet accent 如何实现
2. slow / medium / fast / veryFast accent 强度
3. sparkle ratio
4. sparkle frequency
5. twinkle depth
6. 是否只作用于 Bright Particle
7. text safe zone 如何处理
8. 是否增加新的 TimelineView / Canvas
9. CPU 相比修改前是否变化明显
10. build / tests / diff check
11. slow / medium / fast / veryFast 录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_SPARKLE_TUNING.md` 并严格执行。

本轮只做两个视觉增强：

```text
1. activity 越快 → Compact Bar 右侧略微更偏紫
2. activity 越快 → Bright Particle 星光闪烁感越强
```

Sparkle 必须：

```text
局部
异步
连续
克制
```

不要：

```text
整条 Bar 同步闪
所有粒子一起闪
随机跳变
```

不要增加粒子数量，也不要增加新的 animation clock。

完成后提供 slow / medium / fast / veryFast 录屏进行视觉验收。

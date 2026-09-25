# QuotaBar — Continuous Multi-Stream Particle Architecture

目标仓库：`xzcode/quota-bar`

本轮只重构 Compact Bar 的粒子流模型，彻底解决：

```text
粒子“一波一波”出现
```

的问题。

当前版本已经有：

- 三层景深思路
- 水平流动
- sparkle
- activityLevel
- 紫色 activity accent

这些方向不推翻。

本轮重点是：

> **把“一个大粒子池”改成多个独立、持续、均匀的粒子 Stream。**

---

## 1. 当前问题

当前实现仍然容易出现：

```text
一团粒子经过
→ 中间变稀
→ 下一团再来
```

根因不是粒子数量本身，而是当前：

```text
先生成全局 phase
→ 再把粒子分配到 Far / Mid / Near
```

导致某一 depth layer 内的 phase 并不一定均匀覆盖完整 0...1。

再加上：

```text
Far / Mid / Near 使用不同速度
```

就会形成明显的“波次”。

---

## 2. 新架构

不要再使用：

```text
一个全局粒子池
→ 每颗粒子附带 depth 标签
```

改为：

```text
ParticleFlowSystem
│
├── Far Stream
│   ├── Lane 0 Stream
│   └── Lane 4 Stream
│
├── Mid Stream
│   ├── Lane 1 Stream
│   └── Lane 3 Stream
│
└── Near Stream
    └── Lane 2 Stream
```

每条 Stream：

- 自己拥有完整 phase distribution
- 自己拥有固定速度
- 自己独立 wrap
- 自己保证 0...1 全范围持续有粒子

---

## 3. 最核心原则

每一条 Stream 都必须满足：

```text
任何时刻都有粒子分布在整条 Bar 上
```

不能出现：

```text
这一整条 Stream 的大多数粒子都集中在一侧
```

---

## 4. Stream 独立 Phase Distribution

例如：

### Far lane 0

```text
0--------------------------------1
·   · ·    ·   · ·   ·    · ·
```

### Far lane 4

```text
0--------------------------------1
  ·    ·   · ·     ·    ·   ·
```

### Mid lane 1

```text
0--------------------------------1
 •    •  •     •   •     •
```

### Mid lane 3

```text
0--------------------------------1
   •     •   •     •  •
```

### Near lane 2

```text
0--------------------------------1
     ●        ●      ●       ●
```

每条 lane 自己铺满完整 phase。

---

## 5. 不允许跨 Stream 共用 Phase Pool

禁止：

```text
先生成 90 个 phase
→ 再切一部分给 far
→ 一部分给 mid
→ 一部分给 near
```

这是当前“波次感”的主要来源。

正确做法：

```text
每个 Stream 自己生成 phase
```

---

## 6. Phase 生成方式

每个 Stream 独立使用：

```text
Jittered Stratified Distribution
```

例如某个 Stream 有 12 个粒子：

```text
12 个 slot
→ 每 slot 一个粒子
→ slot 内固定 jitter
```

伪代码：

```swift
let slot = 1.0 / Double(count)

for i in 0..<count {
    let center = (Double(i) + 0.5) * slot
    let jitter = (stableSeed(i) - 0.5) * slot * jitterFactor
    phase = wrapped(center + jitter)
}
```

建议：

```text
jitterFactor = 0.45 ~ 0.65
```

---

## 7. 不使用 Pure Random

禁止：

```text
phase = random(0...1)
```

因为会产生：

```text
聚团
大空洞
```

必须：

```text
先分槽
再轻微 jitter
```

---

## 8. 每个 Stream 一个固定速度

不要每颗粒子随机速度。

每条 Stream 自己一个固定速度。

示例：

```text
Far lane 0  → 0.60×
Far lane 4  → 0.64×

Mid lane 1  → 1.00×
Mid lane 3  → 1.05×

Near lane 2 → 1.65×
```

这样：

- 同一 Stream 内间距永远稳定
- 不追尾
- 不聚团
- 不形成新的空洞
- 不同 Stream 之间持续错位

---

## 9. 三层速度关系

核心：

```text
Far 最慢
Mid 中等
Near 最快
```

推荐视觉倍率：

```text
Far  : 0.55 ~ 0.70
Mid  : 1.00
Near : 1.55 ~ 1.80
```

---

## 10. ActivityLevel 控制 Base Speed

每个 activityLevel 只改变整体 base speed。

例如：

### Slow

```text
Mid base travel = 4.0 ~ 4.5 s
```

### Medium

```text
Mid base travel = 2.8 ~ 3.2 s
```

### Fast

```text
Mid base travel = 1.9 ~ 2.3 s
```

### VeryFast

```text
Mid base travel = 1.1 ~ 1.4 s
```

---

## 11. 密度重新恢复

三层景深不能以牺牲密度为代价。

推荐：

| Activity | Far | Mid | Near | Total |
|---|---:|---:|---:|---:|
| Slow | 16 | 10 | 4 | 30 |
| Medium | 24 | 18 | 6 | 48 |
| Fast | 34 | 26 | 8 | 68 |
| VeryFast | 46 | 34 | 10 | 90 |

---

## 12. Far Layer

Far 粒子最多，但成本最低。

特点：

```text
0.7 ~ 1.2 pt
低 opacity
无 halo
无 radial gradient
无 sparkle
```

只画普通实心小圆。

目标：

```text
铺底
持续存在
形成远景速度参照
```

---

## 13. Mid Layer

特点：

```text
1.2 ~ 1.9 pt
中等 opacity
大部分无 halo
极少 shimmer
```

承担：

```text
主要持续流动感
```

---

## 14. Near Layer

特点：

```text
2.0 ~ 3.4 pt
最亮
最快
数量最少
```

Near Layer 才使用：

```text
halo
sparkle
bright core
```

---

## 15. 性能原则

90 个视觉粒子不等于 90 个昂贵粒子。

必须：

```text
Far → 最便宜
Mid → 中等
Near → 少量 expensive FX
```

禁止：

```text
所有粒子都 radial gradient halo
```

---

## 16. Wrap 必须独立

每颗粒子仍然独立 wrap。

但因为同一个 Stream 内速度一致、phase 分布稳定：

```text
粒子离开左侧
→ 自己从右侧回到对应 phase
```

不能：

```text
整条 Stream reset
```

---

## 17. ActivityLevel 切换

例如：

```text
medium → fast
```

不能整层重新生成 phase。

建议：

- 已存在 Stream 保留当前 phase anchor
- 新增粒子使用该 Stream 预生成 phase
- 新粒子淡入 0.2 ~ 0.4 秒
- 减少粒子时淡出

禁止：

```text
整条 lane 突然重排
```

---

## 18. Bright Particle 选择

Bright 只从 Near Layer 中选择。

不要：

```text
每固定 N 个一个 bright
```

使用：

```text
fixed-seed pseudo-random selection
```

---

## 19. Sparkle

Sparkle 继续只主要作用于 Near Layer。

要求：

- 异步
- 不同步闪
- 不全局 pulse
- 不影响 phase / position

---

## 20. 右侧紫色重新设计

当前问题：

```text
紫色 opacity 在变
但肉眼差异不明显
```

本轮 activityLevel 不只控制：

```text
Purple Strength
```

还要控制：

```text
Purple Coverage
```

也就是：

```text
速度越快
→ 紫色区域从右侧向左扩展
```

---

## 21. Purple Coverage

建议：

```text
Calm:
startX = 0.82

Slow:
startX = 0.78

Medium:
startX = 0.72

Fast:
startX = 0.63

VeryFast:
startX = 0.52
```

这里的 startX 是：

```text
紫色 gradient 开始明显介入的位置
```

---

## 22. Purple Strength

建议右端最终强度：

```text
Calm:
0

Slow:
0.10 ~ 0.14

Medium:
0.16 ~ 0.22

Fast:
0.24 ~ 0.32

VeryFast:
0.34 ~ 0.44
```

视觉必须能在截图中区分：

```text
Slow vs VeryFast
```

---

## 23. 紫色不能变粉

仍然保持：

```text
electric violet
indigo violet
blue-violet
```

不要：

```text
pink
magenta
red
```

除非 quota 本身进入 low / critical。

---

## 24. 粒子也轻微响应紫色区域

当粒子位于右侧 activity accent 区域：

### Far
- 基本不 tint

### Mid
- 轻微 violet tint

### Near
- 更明显一点 violet tint

---

## 25. 文字 Safe Zone

中央：

```text
100% · 45%
```

保持最清楚。

建议：

### Far
正常通过

### Mid
中央 opacity × 0.75 ~ 0.85

### Near
中央 opacity × 0.50 ~ 0.65
sparkle strength 同时降低

---

## 26. 最重要的验收方式

Debug 模式下临时隐藏百分比文字。

连续看：

```text
20 秒
```

如果任何时候明显出现：

```text
一大团粒子
→ 一块空
→ 下一大团
```

则实现失败。

---

## 27. 正确效果

应该始终是：

```text
Far：
一直有慢速小粒子

Mid：
一直有稳定中速粒子

Near：
一直有少量高速粒子快速掠过
```

整体永不断流。

---

## 28. 20 秒验收

必须分别检查：

```text
slow 20 秒
medium 20 秒
fast 20 秒
veryFast 20 秒
```

因为短录屏可能看不出周期性波次。

---

## 29. 不允许修改

禁止：

```text
LocalTokenUsageMonitor
今日 Token 统计
TokenActivityPolicy thresholds
Expanded UI
Compact 尺寸
app-server
JSON-RPC
Quota danger threshold
```

---

## 30. 建议代码结构

建议从当前“大 descriptor pool”重构为：

```swift
ParticleFlowSystem
 ├─ ParticleStream(farLane0)
 ├─ ParticleStream(farLane4)
 ├─ ParticleStream(midLane1)
 ├─ ParticleStream(midLane3)
 └─ ParticleStream(nearLane2)
```

每个 `ParticleStream` 自己保存：

```text
phase descriptors
speed multiplier
depth
lane
particle count
```

---

## 31. CPU 要求

目标：

```text
修复 wave 问题
同时不明显增加 CPU
```

允许：

```text
一次性生成 5 个 Stream descriptor
```

禁止：

```text
每帧 random
每帧重建数组
每帧排序
新增 TimelineView
新增多个 Canvas
```

仍使用：

```text
一个 Canvas
一个 TimelineView
```

---

## 32. 最终汇报

完成后停止开发并汇报：

```text
1. 是否彻底移除全局 phase pool
2. 共创建多少独立 Stream
3. 每个 Stream 的 particle count
4. 每个 Stream 的 phase 生成方式
5. 每个 Stream 的 speed
6. activity 切换是否保持 phase
7. 是否还出现 wave / burst
8. Purple Coverage startX 各等级
9. Purple Strength 各等级
10. CPU 是否变化明显
11. build / tests / diff check
12. slow / medium / fast / veryFast 各 20 秒录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_CONTINUOUS_STREAM_ARCHITECTURE.md` 并严格执行。

当前最大问题：

```text
粒子仍然一波一波出现
```

本轮不要再继续调整：

```text
opacity
size
sparkle
```

来掩盖问题。

直接修复粒子流结构：

```text
一个全局粒子池
→
5 个独立 Continuous Stream
```

每条 Stream 必须：

```text
独立覆盖完整 0...1 phase
固定 lane
固定速度
独立 wrap
持续不断
```

同时保留：

```text
Far / Mid / Near 景深
Dense Particle Stream
Sparkle
右侧 activity 紫色
```

并让右侧紫色不仅“更亮”，还要随着速度提升从右向左扩大覆盖范围。

不要修改 Token 统计和业务逻辑。

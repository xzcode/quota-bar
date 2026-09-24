# QuotaBar — Particle Flow Naturalization

目标仓库：`xzcode/quota-bar`  
当前实现基线：`a56d69ffb4aeba23abcf11f368168044aa9d9d05`

本轮只处理一个问题：

> 当前粒子虽然密集、连续、水平，但整体间距过于规则，像“移动的 LED 点阵”。

目标是：

> 保留连续、水平、稳定的优点，同时让粒子分布更自然、更像星尘数据流。

不要修改：

- LocalTokenUsageMonitor
- token_count 解析
- 今日 Token 统计
- TokenActivityPolicy 阈值
- app-server / JSON-RPC
- Expanded UI
- Compact Bar 尺寸
- calm = 0 FPS
- 粒子总数量级
- 当前 sparkle 逻辑的整体方向

---

## 1. 当前问题根因

当前 `DenseParticleStreamView` 中，粒子初始 phase 使用：

```swift
(Double(index) + 0.5) / Double(count)
```

后续增加粒子时又使用：

```swift
fillLargestGaps(...)
```

这会主动把粒子插入当前最大空隙中。

结果是：

```text
•   •   •   •   •   •   •
```

间距趋向规则。

同时，当前所有粒子使用同一个水平速度：

```swift
phase += elapsed / travelTime
```

因此：

```text
初始间距一旦确定
→ 运行多久都不会变化
```

Bright Particle 当前又通过固定 stride：

```swift
stride(..., by: 8)
```

选择，因此亮点分布也带有机械规律。

---

## 2. 本轮目标

把视觉从：

```text
规则点阵
```

升级为：

```text
自然、连续、稳定的星尘数据流
```

要求：

- 不出现一波一波
- 不出现大片空白
- 不乱串
- 不上下漂
- 不追尾
- 不产生突发聚团
- 不破坏水平流动
- 不增加明显 CPU 开销

---

## 3. 核心方案

采用：

```text
Jittered Stratified Phase
+
Per-Lane Stable Speed
+
Pseudo-Random Bright Distribution
```

不要使用：

```text
每颗粒子完全随机速度
```

因为那会造成：

```text
追尾
聚团
空档
周期性重叠
```

---

## 4. Jittered Stratified Phase

不要再把粒子放在完全均匀的 phase 中心。

当前类似：

```text
|  • |  • |  • |  • |  • |
```

改成：

```text
| •  |   •| •  |    •|  • |
```

也就是说：

先做 stratified bins：

```text
0..1
```

分成 N 个槽位。

每个粒子仍然属于自己的槽位，但在槽位内部加入固定 jitter。

---

## 5. Jitter 范围

建议：

```text
slot center ± 25% ~ 35% slot width
```

例如：

```swift
let slot = 1.0 / Double(count)
let center = (Double(index) + 0.5) * slot
let jitter = (seed - 0.5) * slot * 0.6
let phase = wrapped(center + jitter)
```

建议初始 jitter factor：

```text
0.45 ~ 0.70
```

实际视觉决定最终值。

---

## 6. Jitter 必须固定

phase jitter 必须由固定 seed 产生。

例如：

```swift
seed(index, salt: ...)
```

禁止：

```text
每帧 random
每次 wrap random
每次 level change random
```

否则会出现跳跃。

---

## 7. 不再使用 fillLargestGaps 作为最终分布逻辑

`fillLargestGaps()` 的设计目标是均匀填空，因此天然会产生机械感。

本轮建议：

```text
停止将 fillLargestGaps 用作常态 phase 生成算法
```

Dense Particle Stream 的默认 descriptor 生成改为：

```text
jittered stratified phases
```

---

## 8. Activity Level 增加粒子时

从：

```text
slow → medium → fast → veryFast
```

不能整批 reset phase。

新增粒子应：

```text
使用预生成 descriptor phase
渐入
```

已有粒子保留当前位置。

---

## 9. 每 Lane 独立稳定速度

不要所有 lane 完全同速。

建议 5 条 lane 使用固定 multiplier：

```text
lane 1: 0.93
lane 2: 1.04
lane 3: 0.97
lane 4: 1.08
lane 5: 1.00
```

允许范围：

```text
0.92 ~ 1.08
```

---

## 10. 为什么是 Lane Speed，而不是 Particle Speed

同一 lane 内所有粒子速度相同。

这样：

```text
同 lane 粒子间距不会改变
不会追尾
不会聚团
```

不同 lane 速度略有差异，因此 lane 之间会缓慢错位。

整体视觉会持续变化，不再像固定点阵整体平移。

---

## 11. Lane Speed 必须固定

建议：

```swift
private let laneSpeedMultiplier: [Double] = [
    0.93,
    1.04,
    0.97,
    1.08,
    1.00
]
```

运行期间不能变化。

---

## 12. Position 计算

当前：

```swift
phase = anchor + elapsed / travelTime
```

改为：

```swift
phase = anchor
    + elapsed / travelTime
    * laneSpeedMultiplier[lane]
```

只影响水平 phase。

y 继续固定。

---

## 13. 不允许上下漂移

本轮仍保持：

```text
laneY 固定
```

不要重新加入：

```text
sin wave
vertical jitter animation
lane switching
```

自然感来自：

```text
水平间距
lane 速度差异
亮点分布
```

---

## 14. Bright Particle 分布改造

当前：

```swift
stride(from: 2, ..., by: 8)
```

导致每 8 个粒子一个亮点，过于规律。

改为：

```text
固定 seed 的 pseudo-random selection
```

---

## 15. Bright Particle 数量保持不变

不要增加亮粒子数量。

继续保持当前各等级对应的 `brightParticleCount`。

只改变：

```text
哪些 particle ID 是 bright
```

---

## 16. Bright Particle 选择规则

从最大 descriptor pool 中：

```text
使用固定 hash / seed 排序
```

例如：

```swift
let rankedIndices = allIndices.sorted {
    seed($0, salt: brightSalt) < seed($1, salt: brightSalt)
}
```

然后取前 `brightParticleCount` 个作为 bright。

这样：

- 每次启动结果稳定
- 分布不再机械
- 不需要 runtime random

---

## 17. Sparkle Rank 也改成固定随机顺序

对 bright particle 再做一次 fixed-seed ranking。

让不同 bright particle 获得不同：

```text
sparkleRank
twinklePhase
twinkleDepth
twinkleSpeed
```

保留当前异步 twinkle 思路。

---

## 18. 视觉目标示意

当前像：

```text
lane1   •    •    •    •    •
lane2     •    •    •    •
lane3   •    •    •    •    •
lane4     •    •    •    •
lane5   •    •    •    •    •
```

目标更像：

```text
lane1   • •       •    ••       •
lane2      •   •       • •   •
lane3  •       • •        •     •
lane4    • •         •      • •
lane5  •     •    ••         •
```

但仍然不能出现超大空洞。

---

## 19. 最小间距保护

Jitter 不能太大。

建议保持：

```text
minimum phase gap
≈ 0.25 ~ 0.35 × average slot width
```

如果两个 phase 太近：

```text
轻微推开
```

不要重新完全均匀化。

---

## 20. 最大空洞保护

建议：

```text
maximum gap
<= 1.8 ~ 2.2 × average slot width
```

超过时只做轻量修正。

目标：

```text
自然
但不失控
```

---

## 21. 不需要真实 Random

全部使用 deterministic seed。

好处：

```text
视觉稳定
可测试
可复现
不跳变
几乎无额外 runtime 成本
```

---

## 22. CPU 要求

本轮优化不能提高 CPU。

只允许增加：

```text
一次性 descriptor 生成
每帧一个 lane speed multiplier
```

禁止：

```text
每帧 random
每帧重新排序
每帧重新生成 descriptor
新增 Canvas
新增 TimelineView
```

---

## 23. Demo Mode 验收

继续用：

```text
slow
medium
fast
veryFast
```

重点确认：

- slow：不再像规则点阵
- medium：粒子增多但间距不机械
- fast：密集但自然
- veryFast：大量粒子高速流动，但不聚团、不一波一波、不产生明显重复 pattern

---

## 24. 必须录屏

每档至少：

```text
8 ~ 10 秒
```

因为需要观察：

```text
不同 lane 是否会逐渐错位
pattern 是否重复得太明显
是否会慢慢聚团
```

---

## 25. 本轮禁止修改

禁止修改：

```text
粒子总数量
FPS
travel time
right violet accent
sparkle frequency/depth
LocalTokenUsageMonitor
TokenActivityPolicy
Expanded UI
Compact 尺寸
app-server
JSON-RPC
```

只处理：

```text
particle spacing
lane speed
bright distribution
```

---

## 26. 推荐修改文件

重点：

```text
DenseParticleStreamView.swift
```

必要时：

```text
TokenActivityEnergyStyle.swift
```

但不要大规模重构。

---

## 27. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 28. 最终汇报

完成后停止开发，并汇报：

```text
1. jittered stratified phase 如何实现
2. jitter 范围
3. minimum gap
4. maximum gap
5. lane speed multiplier
6. 是否使用 per-particle speed
7. bright particle 如何 pseudo-random 选择
8. sparkle rank 如何分布
9. activity level 切换是否会 reset phase
10. CPU 是否变化
11. build / tests / diff check
12. slow / medium / fast / veryFast 录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_PARTICLE_NATURALIZATION.md` 并严格执行。

当前问题：

```text
粒子 phase 过度均匀
全体粒子水平速度完全一致
bright particle 每固定 N 个出现
```

导致 Compact Bar 看起来像：

```text
移动的 LED 点阵
```

本轮目标：

```text
Jittered Stratified Phase
+
Per-Lane Stable Speed
+
Pseudo-Random Bright Distribution
```

最终视觉应该更像：

```text
连续流动的星尘数据流
```

但必须继续保持：

```text
水平
稳定
不聚团
不一波一波
不跳跃
低额外 CPU
```

不要修改粒子数量、FPS、Token 逻辑和业务逻辑。

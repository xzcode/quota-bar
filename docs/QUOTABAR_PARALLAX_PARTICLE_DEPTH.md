# QuotaBar — Parallax Particle Depth Redesign

目标仓库：`xzcode/quota-bar`

本轮重新设计 Compact Bar 的动态视觉。

这次不再只优化“粒子分布自然度”，而是明确引入：

```text
空间层次感（Parallax Depth）
```

核心目标：

1. 粒子流形成 **近 / 中 / 远 三层空间层次**
2. 越近的粒子：
   - 更大
   - 更亮
   - 更快
3. 越远的粒子：
   - 更小
   - 更淡
   - 更慢
4. 三层共同形成：
   - 速度感
   - 深度感
   - 持续流动感
5. 修复：
   - 右侧紫色区域没有随着 activityLevel 明显增强的问题

不要修改：

- LocalTokenUsageMonitor
- token_count 解析
- 今日 Token 统计
- TokenActivityPolicy 阈值
- app-server / JSON-RPC
- Expanded UI
- Compact Bar 尺寸
- calm = 0 FPS
- Quota danger threshold
- 业务逻辑

---

## 1. 这次的核心视觉目标

当前问题不是“粒子不够多”，而是：

```text
虽然有流动
但缺少空间层次
缺少前后景深关系
速度感不够立体
```

用户希望的感觉是：

> 像开车时看外面的景物一样：
>
> - 近处东西掠过得更快
> - 远处东西移动得更慢
> - 前后层叠加后，速度感会更强

Compact Bar 里也要实现这个效果。

---

## 2. 视觉模型改为“三层粒子流”

Dynamic layer 改为：

```text
Far Layer
+
Mid Layer
+
Near Layer
+
Soft Energy Background Glow
```

不要再把所有粒子当成同一层来画。

---

## 3. 三层定义

### Far Layer（远景层）

作用：

```text
提供背景速度参照
衬托空间深度
让整体看起来更有层次
```

特点：

- 最小
- 最淡
- 最慢
- 数量可以较多
- 尽量不抢眼

---

### Mid Layer（中景层）

作用：

```text
作为主流层
承担大部分持续流动感
```

特点：

- 中等大小
- 中等亮度
- 中等速度
- 数量较多

---

### Near Layer（近景层）

作用：

```text
承担最强速度感
承担最明显的“星光掠过感”
```

特点：

- 最大
- 最亮
- 最快
- 数量相对较少
- 但最显眼

---

## 4. 三层必须同时水平流动

所有层都必须：

```text
严格水平
同方向
稳定连续
```

不要重新引入：

```text
上下乱漂
斜向运动
随机换道
大幅 wave
```

深度感来自：

```text
大小差异
亮度差异
速度差异
```

而不是轨迹混乱。

---

## 5. Lane 体系保留，但分层使用

继续使用固定 lane 的思路。

建议总共使用 5 条 lane，但分配给不同 depth layer：

```text
lane 1
lane 2
lane 3
lane 4
lane 5
```

推荐分配：

### Far Layer
- lane 1
- lane 5

### Mid Layer
- lane 2
- lane 4

### Near Layer
- lane 3 为主
- 必要时可少量占用 lane 2 / lane 4 的近中景版本

目标是让画面中央附近有最强速度感，但不能压住文字。

---

## 6. 近 / 中 / 远 的大小建议

### Far Layer

```text
diameter:
0.7 ~ 1.2 pt
```

### Mid Layer

```text
diameter:
1.2 ~ 1.9 pt
```

### Near Layer

```text
diameter:
2.0 ~ 3.2 pt
```

Near Layer 中少量 bright particle 可再稍大一些，但不要超过约 3.6pt。

---

## 7. 近 / 中 / 远 的亮度建议

### Far Layer

```text
opacity:
0.08 ~ 0.20
```

### Mid Layer

```text
opacity:
0.18 ~ 0.42
```

### Near Layer

```text
opacity:
0.45 ~ 0.95
```

Near Layer 的 bright 粒子可以配轻微 halo。

Far Layer 不要做明显 halo。

---

## 8. 近 / 中 / 远 的速度建议

这是本轮最关键点。

每个 activityLevel 下，都要同时存在三档速度。

建议使用：

```text
base travel time
× depth multiplier
```

例如：

### Slow
base travel time:
```text
4.2 s
```

### Medium
base travel time:
```text
3.0 s
```

### Fast
base travel time:
```text
2.1 s
```

### VeryFast
base travel time:
```text
1.3 s
```

然后三层乘数：

### Far Layer
```text
1.45 ~ 1.65
```

### Mid Layer
```text
1.00
```

### Near Layer
```text
0.62 ~ 0.78
```

也就是说：

- far 更慢
- mid 作为基准
- near 明显更快

---

## 9. 举例

例如在 `Fast`：

base = `2.1 s`

可得：

### Far
```text
约 3.1 ~ 3.4 s
```

### Mid
```text
约 2.1 s
```

### Near
```text
约 1.3 ~ 1.6 s
```

用户就会明显感到前后景速度差异。

---

## 10. 数量分配建议

总粒子数量不一定需要增加太多，但需要合理分层。

### Slow

```text
Far:  6 ~ 8
Mid:  6 ~ 8
Near: 2 ~ 3
```

### Medium

```text
Far:  8 ~ 10
Mid: 10 ~ 12
Near: 3 ~ 4
```

### Fast

```text
Far:  10 ~ 14
Mid:  12 ~ 16
Near:  4 ~ 6
```

### VeryFast

```text
Far:  12 ~ 16
Mid:  16 ~ 22
Near:  6 ~ 8
```

重点不是盲目加总量，而是形成：

```text
远景铺底
中景主流
近景冲刺
```

---

## 11. 三层粒子分布原则

### Far Layer
- 最均匀
- 可以更密
- 但很淡

### Mid Layer
- 主流层
- 最稳定
- 是视觉主体

### Near Layer
- 更稀一些
- 但更亮、更快
- 用来“点燃速度感”

不要让 Near Layer 数量过多，否则会把整个画面搞乱。

---

## 12. Sparkle 只主要作用于 Near Layer

当前“星光闪烁”方向可以保留，但要更明确地绑定层级。

建议：

### Far Layer
- 无 sparkle
- 或几乎不可见

### Mid Layer
- 极弱 shimmer
- 如不干净可关闭

### Near Layer
- 承担主要 sparkle
- 承担主要高亮点

这样可以自然形成：

```text
远处平稳
近处活跃
```

---

## 13. Sparkle 规则

Near Layer 的 bright particle 可继续使用：

```text
twinklePhase
twinkleSpeed
twinkleDepth
```

但要遵守：

- 异步
- 连续
- 局部
- 不同步
- 不全局闪

可以理解为：

> 近景粒子在高速掠过时更容易“catch light”

---

## 14. 右侧紫色区域修复

用户已经明确指出：

> 右边的紫色并没有随着速度变化。

这说明当前实现强度不够，或者被其他层覆盖掉了。

这次要明确修复。

---

## 15. 右侧紫色增强目标

希望：

### Slow
- 右侧只有很轻微的紫色活动区

### Medium
- 右侧紫感开始明显

### Fast
- 右侧明显更偏紫

### VeryFast
- 右侧最明显地带有紫色能量活跃区

注意：

- 仍然保持蓝紫体系
- 不要变粉
- 不要变危险红
- danger color 逻辑继续独立

---

## 16. 推荐的右侧紫色实现方式

不要只做一个非常淡的 overlay。

建议至少叠加三部分：

```text
1. Right Violet Radial Glow
2. Right Side Color Overlay
3. Near/Mid Layer 粒子在右侧轻微偏紫
```

---

## 17. Right Violet Radial Glow

建议：

```text
位置：
x ≈ 82% ~ 96%
y ≈ 50%

半径：
14 ~ 26 pt
```

opacity 随 activityLevel 提升：

### Slow
```text
0.05 ~ 0.08
```

### Medium
```text
0.10 ~ 0.14
```

### Fast
```text
0.18 ~ 0.24
```

### VeryFast
```text
0.26 ~ 0.34
```

---

## 18. Right Side Overlay

再加一层从中右部向右端渐强的 overlay：

```text
透明
→ 极淡 violet
→ 更浓一点的 violet
```

范围建议：

```text
x 65% ~ 100%
```

opacity 也按 activityLevel 递增。

这层应该让用户即使静止截图也能明显看出：

```text
veryFast 比 slow 更紫
```

---

## 19. 粒子颜色也要轻微随右侧区域偏移

仅靠背景 glow 可能还不够明显。

建议在粒子着色时加入一个 very light tint bias：

```text
粒子越靠近右侧
→ 越容易偏蓝紫 / violet
```

只需要轻微，不要所有粒子都紫化。

Near / Mid Layer 更适合做这个偏移；
Far Layer 可以弱一点甚至忽略。

---

## 20. Text Safe Zone

中央数字：

```text
96% · 47%
```

仍必须最清楚。

三层粒子都可以经过中央区域，但要做强度控制：

### Far
- 可正常通过

### Mid
- 中央区域 opacity 稍降

### Near
- 中央区域显著降亮度 / 降 sparkle 强度

右侧紫色增强不能影响中央文字可读性。

---

## 21. 自然分布保留

上一个版本的自然化方向不要丢：

- jittered stratified phase
- per-lane stable speed
- pseudo-random bright distribution

这些都继续保留。

本轮是在这个基础上继续升级，不要退回规则点阵。

---

## 22. 不能回到“乱”

虽然现在要做三层速度，但不能变成：

```text
每颗粒子一个完全随机速度
```

建议：

### depth layer 决定主速度
### lane 再给少量固定 multiplier

例如：

```text
Near Layer lane 3: 1.00
Near Layer lane 2/4 variant: 0.96 / 1.04

Mid Layer lane 2/4: 0.97 / 1.03

Far Layer lane 1/5: 0.95 / 1.05
```

这样既有层次，又不会乱。

---

## 23. CPU 要求

本轮不要显著增加 CPU。

允许增加：

- depth layer 逻辑
- 每帧多几个乘数
- 右侧 glow / overlay

不允许：

- 新增多套 TimelineView
- 新增多个 Canvas 反复叠加
- 每帧 random
- 每帧重建 descriptor

仍应尽量保持：

```text
一个主 Canvas + 现有动画时钟
```

---

## 24. 优先级

本轮优先级：

### P1
三层速度深度感（近中远）

### P2
右侧紫色 activity accent 修复

### P3
保留自然化分布，不要再像点阵

### P4
继续保持 sparkle 的高级感

---

## 25. 建议修改文件

重点：

```text
DenseParticleStreamView.swift
DynamicEnergyLayer.swift
SoftEnergyGlow.swift
TokenActivityEnergyStyle.swift
```

如必要可以新增非常小的辅助 model，但不要大重构。

---

## 26. 视觉验收标准

### Slow
- 层次轻微，但能看出近中远
- 右侧紫色很弱但存在

### Medium
- 已经能感受到空间层次
- 右侧紫色比 slow 更明显

### Fast
- 近景粒子明显比远景快
- 画面更有冲刺感
- 右侧紫色明显增强

### VeryFast
- 最强空间速度感
- 近景掠过感明显
- 远景层稳定衬托
- 右侧紫色最明显
- 仍然不乱、不闪烁过头

---

## 27. 必须录屏

完成后提供：

```text
slow 8 秒
medium 8 秒
fast 8 秒
veryFast 8 秒
```

重点检查：

- 是否能看出近中远三层速度差
- 右侧紫色是否真的随速度增强
- 是否保持水平稳定
- 是否仍然自然不机械
- 是否没有重新变乱

---

## 28. 本轮禁止修改

禁止：

```text
LocalTokenUsageMonitor
今日 Token 统计
TokenActivityPolicy threshold
Quota danger threshold
Expanded UI
Compact 尺寸
app-server
JSON-RPC
```

不要引入新的业务功能。

---

## 29. Build / Tests

完成后运行：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 30. 最终汇报

完成后停止开发，并汇报：

```text
1. 三层粒子如何建模
2. far / mid / near 的大小、亮度、数量
3. far / mid / near 的 travel time 或 speed multiplier
4. 是否保留 jittered stratified phase
5. per-lane speed 如何与 depth layer 结合
6. sparkle 主要作用于哪一层
7. 右侧紫色增强如何实现
8. slow / medium / fast / veryFast 的紫色强度
9. CPU 是否显著变化
10. build / tests / diff check
11. slow / medium / fast / veryFast 录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_PARALLAX_PARTICLE_DEPTH.md` 并严格执行。

当前问题：

```text
粒子虽然已经更自然了，但仍然缺少空间层次感；
右侧紫色也没有明显随 activityLevel 提升。
```

本轮目标：

```text
Far / Mid / Near 三层粒子流
+
近大快亮、远小慢淡
+
右侧紫色 activity accent 明显随速度增强
```

最终视觉要像：

```text
高速流动的数据星尘
```

并有类似“开车看景物前后速度差”的层次感。

但必须继续保持：

```text
水平
连续
稳定
不聚团
不乱跳
不明显增 CPU
```

不要修改 Token 统计与业务逻辑。

# QuotaBar — Energy FX V3

目标仓库：`xzcode/quota-bar`

本轮只优化 Compact Bar 的动态运动组织与速度感。

不要修改：

- LocalTokenUsageMonitor
- token_count 解析
- 今日 Token 统计
- TokenActivityLevel 阈值
- app-server / JSON-RPC
- Expanded 卡片布局
- Compact Bar 尺寸
- calm = 0 FPS 的省电策略

---

## 1. 当前问题

当前动态效果主要有四个问题：

1. 发光 comet 会上下乱串，不够水平
2. 没有光点的 streak / ribbon 运动比较乱，甚至有跳跃感
3. fast / veryFast 的整体速度不够快
4. 动态元素密度偏低，没有持续的“高速能量流”感觉

目标不再是“自由漂浮粒子”，而是：

> **有组织的水平高速能量流**

---

## 2. 运动原则

所有主要动态元素都使用固定水平轨道。

不要：

```text
上下乱漂
斜向飞行
随机换轨
大幅正弦波
每帧随机 y
```

允许的纵向变化：

```text
最多 ±0.4 pt
```

也就是说，视觉上必须基本是纯水平运动。

---

## 3. 固定 Lane 系统

针对当前 `210 × 32` Compact Bar，定义四条固定轨道：

```text
lane 1: y = 7
lane 2: y = 12
lane 3: y = 20
lane 4: y = 25
```

建议分工：

```text
lane 1:
细 streak

lane 2:
主 comet

lane 3:
主 comet

lane 4:
细 streak
```

可以让不同实例有轻微 ±0.3~0.4pt 偏移，但不能跨 lane。

---

## 4. 发光 Comet

这是最重要的视觉元素。

当前用户反馈：

> 带光点的流星效果是可以的，但应该水平飞。

因此保留并加强 comet。

要求：

- 必须严格水平移动
- 不要斜飞
- 不要上下乱串
- 不要突然跳 lane
- 轨迹必须连续
- comet 的 y 一旦确定，在生命周期内保持稳定

---

## 5. Comet 视觉结构

每个 comet：

```text
Bright Core
+
Colored Halo
+
Long Gradient Tail
```

颜色：

```text
core:
white / pale cyan

halo:
cyan-blue / electric blue

tail:
cyan → blue → violet → transparent
```

不要只画：

```text
白点 + 白线
```

---

## 6. Comet 尺寸

建议：

```text
active:
core 2.8 ~ 3.2 pt

fast:
core 3.2 ~ 3.6 pt

veryFast:
core 3.6 ~ 4.0 pt
```

Halo：

```text
比 core 大 4 ~ 7 pt
```

Halo 需要柔和，不要变成大光球。

---

## 7. Comet Tail 长度

当前尾巴仍偏短。

建议：

```text
active:
10 ~ 14 pt

fast:
22 ~ 30 pt

veryFast:
32 ~ 46 pt
```

Tail：

```text
亮端靠近 core
向后逐渐透明
轻微 blur
```

必须表现出高速感。

---

## 8. Comet 数量

建议：

```text
active:
1

fast:
2 ~ 3

veryFast:
3 ~ 4
```

不要所有 comet 同 phase。

需要错开：

```text
spawn phase
speed
lane
```

但方向统一。

---

## 9. 非发光 Streak

用户明确反馈：

> 旁边那些没有光点的流星动起来很乱，还有点跳跃。

因此这些 streak 必须重新设计。

它们的定位：

```text
只提供速度感
不是主视觉
```

要求：

- 完全水平
- 固定 lane
- 不做 wave
- 不上下漂
- 不跳跃
- 不闪烁
- 不随机切换轨道
- 长度与速度在生命周期中保持稳定

---

## 10. Streak 数量

为了提高密度：

```text
active:
3 ~ 4

fast:
6 ~ 8

veryFast:
8 ~ 12
```

总数量仍需可控。

不要全部同时最亮。

建议：

```text
约 70% 很淡
约 20% 中等
约 10% 稍亮
```

---

## 11. Streak 长度

建议：

```text
short:
12 ~ 18 pt

medium:
20 ~ 32 pt

long:
34 ~ 46 pt
```

不同 streak 可以有长度差异，但不要每帧变化。

---

## 12. Streak 颜色

不要全部白色。

建议：

```text
cyan-blue
electric blue
violet
```

透明度：

```text
0.12 ~ 0.35
```

少量可达到：

```text
0.45
```

但不要抢 comet。

---

## 13. 速度整体提高

当前 fast / veryFast 仍然显得慢。

建议 travel time：

```text
active:
4.8 ~ 5.5 秒

fast:
2.4 ~ 3.2 秒

veryFast:
1.4 ~ 2.0 秒
```

这些时间指：

```text
从 Bar 一侧完整穿过到另一侧
```

Comet 可以略快于 streak。

---

## 14. 速度差异

不要所有元素同速，但差异不能太大。

建议：

```text
baseSpeed ± 10% ~ 15%
```

不要之前那种太杂的 speed variation。

目标：

```text
像多条同向高速车流
```

而不是：

```text
每个粒子各飞各的
```

---

## 15. Ribbon / Aurora Stream

当前 ribbon 也容易制造乱感。

V3 中请简化。

### Active

```text
最多 1 条
贴近上方或下方 lane
```

### Fast

```text
2 条
分别贴近上 / 下区域
```

### VeryFast

```text
2 条主流
最多额外 1 条极淡 secondary flow
```

不要让 ribbon 在整个 32pt 高度中上下摆动。

---

## 16. Ribbon 垂直运动

取消明显 sinusoidal y movement。

最多：

```text
±0.3 ~ 0.5 pt
```

几乎可以视为水平。

如果仍显得乱：

```text
直接完全固定 y
```

优先稳定性。

---

## 17. Ribbon 形状

不要再像：

```text
~~波浪线~~
```

更像：

```text
柔和水平能量带
```

可以有：

```text
极轻微弯曲
```

但不应该让用户明显看到上下波浪。

---

## 18. Text Safe Zone

中央：

```text
89% · 62%
```

必须始终最清楚。

建议将主要高亮元素放在：

```text
顶部 lane
底部 lane
文字左右侧
```

动态元素经过中央文字区域时：

```text
opacity × 0.35 ~ 0.55
```

避免抢字。

---

## 19. 更高密度，但不能乱

本轮核心之一：

> 提高视觉密度。

正确方式不是加随机粒子，而是：

```text
更多固定 lane 的 streak
+
更长 comet tail
+
更短 travel time
```

这样可以同时得到：

```text
更快
更密
更整齐
```

---

## 20. Active 目标

视觉：

```text
1 comet
3~4 streak
1 soft flow
```

感觉：

```text
开始工作了
```

仍然克制。

---

## 21. Fast 目标

视觉：

```text
2~3 comet
6~8 streak
2 horizontal flows
明显 tail
```

感觉：

```text
Codex 正在高速工作
```

用户一眼就能感受到。

---

## 22. VeryFast 目标

视觉：

```text
3~4 comet
8~12 streak
2 main flow
1 optional faint secondary flow
更长 tail
更快速度
```

感觉：

```text
高吞吐能量流
```

但仍然：

```text
不闪烁
不乱跳
不爆炸
```

---

## 23. Spawn / Phase 必须连续

当前“跳跃感”必须彻底避免。

每个元素应使用稳定 seed：

```text
id
lane
phaseOffset
speedMultiplier
length
opacity
```

这些参数在元素生命周期中固定。

位置只由：

```text
elapsed time
+
固定 seed
```

连续计算。

禁止：

```text
每帧重新随机
```

---

## 24. Wrap Around

元素从左侧离开后重新出现在右侧时：

```text
不能瞬间在用户视野中央跳出来
```

Wrap 必须发生在：

```text
Bar 边界外
```

建议：

```text
x travel range:
width + tailMargin
```

例如：

```text
从 x = width + 40
移动到 x = -40
```

这样循环切换发生在可视区外。

---

## 25. Edge Entry / Exit

Comet 和 streak：

```text
进入时：
tail 先进入或 core 平滑进入

离开时：
完整离开后再 wrap
```

不要：

```text
core 突然消失
下一帧另一边突然出现
```

---

## 26. FPS 保持不变

仍然：

```text
calm     0 FPS
active   12 FPS
fast     18 FPS
veryFast 24 FPS
```

速度提升通过：

```text
travel time
```

实现，而不是提升刷新率。

---

## 27. Calm 继续完全静态

不要改：

```text
calm = 0 FPS
无 DynamicEnergyLayer
```

这是核心省电设计。

---

## 28. Debug Demo Mode

继续保留 DEBUG 状态切换：

```text
calm
active
fast
veryFast
```

本轮视觉调试必须使用 Demo Mode。

不要依赖实际 Token rate 才能调 veryFast。

---

## 29. 视觉验收重点

### Active

- 水平
- 稳定
- 不乱

### Fast

- 明显更快
- 明显更密
- comet 易见
- streak 整齐
- 不跳跃

### VeryFast

- 高速
- 密度高
- 仍然有组织
- 不像随机粒子系统

---

## 30. 必须录屏验收

截图不能验证跳跃和速度。

请提供：

```text
active 5 秒录屏
fast 5 秒录屏
veryFast 5 秒录屏
```

重点检查：

```text
是否严格水平
是否有随机上下串动
是否有 wrap 跳跃
密度是否足够
fast / veryFast 是否真正更快
```

---

## 31. 本轮不要修改

禁止修改：

```text
Token usage monitor
今日 302M 等统计
TokenActivityPolicy 阈值
QuotaDangerState
Expanded UI
窗口尺寸
额度协议
app-server
JSON-RPC
```

---

## 32. 推荐主要修改文件

重点检查：

```text
DynamicEnergyLayer.swift
EnergyRibbonView.swift
ParticleFlowView.swift
```

如已有：

```text
AuroraStreamView
CometFlowView
```

可继续修改。

不要为了本轮大规模重构。

---

## 33. Build / Tests

完成后运行：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 34. 最终汇报

完成后停止开发，并汇报：

```text
1. 固定 lane 如何实现
2. comet 是否完全水平
3. streak 是否完全水平
4. 是否移除了大幅 wave
5. wrap 如何保证不跳跃
6. active / fast / veryFast travel time
7. 各等级 comet 数量
8. 各等级 streak 数量
9. comet trail 长度
10. FPS
11. build / tests / diff check
12. active / fast / veryFast 录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_ENERGY_FX_V3.md` 并严格执行。

本轮目标不是继续增加随机特效，而是把现有 Energy FX 变成：

```text
固定水平轨道
+
高速 Comet
+
整齐 Streak
+
更高但有组织的密度
```

特别修复：

```text
光点流星上下乱串
无光点 streak 运动混乱
wrap / phase 造成的跳跃感
fast / veryFast 速度不够
整体密度不足
```

所有主要元素必须水平运动。

不要修改 Token 数据与业务逻辑。

完成后必须提供 active / fast / veryFast 录屏进行验收。

# QuotaBar — Parallax Density Balance & Multi-Lane Distribution

目标仓库：`xzcode/quota-bar`

本轮只优化 Compact Bar 的粒子视觉分布与层次表现。

当前用户反馈非常明确：

```text
1. 效果有点奇怪
2. 粒子整体偏小
3. 最大粒子几乎只在中间那一条直线上出现
4. 希望每一层显示更多、更均匀的粒子
```

本轮目标不是推翻已有的连续多 Stream 架构，而是在其基础上修正：

```text
粒子尺寸
多层分布
多 lane 分布
每层密度均匀性
```

不要修改：

- LocalTokenUsageMonitor
- token_count 解析
- 今日 Token 统计
- TokenActivityPolicy 阈值
- Expanded UI
- Compact Bar 尺寸
- calm = 0 FPS
- app-server / JSON-RPC
- 业务逻辑

---

## 1. 当前问题判断

从当前截图看，确实存在下面几个问题：

### 1.1 粒子整体偏小

虽然已经有 far / mid / near 三层，但：

- far 太小太淡
- mid 也偏保守
- near 数量少且尺寸不够有存在感

所以用户视觉上会觉得：

```text
只有一些零散小点
```

而不是：

```text
一条有层次感的数据粒子流
```

---

### 1.2 最大粒子过度集中在中间一条 lane

当前架构里，Near Layer 基本只在：

```text
lane 2（中间）
```

活动。

结果就是：

- 最大最亮的粒子只沿中线经过
- 视觉中心过于“线性”
- 上下空间没有被充分利用
- 整个 Bar 看起来像：
  - 中间一根明显主通道
  - 上下只是陪衬碎点

这就是用户说的：

> 最大的粒子都只是在中间那行直线显示

---

### 1.3 每层粒子覆盖还不够均匀

虽然已经避免了“一波一波”，但当前每层仍然显得：

- 某些区域粒子少
- 某些 lane 参与度不够
- 上下层次不够丰富

所以整体会显得：

```text
有结构
但不丰满
```

---

## 2. 本轮设计目标

我们想要的不是“只在中间有大粒子”。

而是：

> **每一层都更丰富，每一层都更均匀，同时保持近中远层次。**

最终希望看到：

```text
Far  层：上中下都能持续看到很多细小慢粒子
Mid  层：形成稳定主流，覆盖更广
Near 层：更大的亮粒子不只在中线，也会分布在中心附近的多条 lane 上
```

视觉上应该像：

```text
上层：  ·   ·  •   ·   •   ·
中层：    •   ●   •   ●   •
下层：  ·  •   ·   •   ·   •
```

而不是：

```text
上层： ·   ·   ·   ·
中层：      ●      ●
下层： ·   ·   ·   ·
```

---

## 3. 保留三层，但重新分配 lane

不要取消三层景深。

继续保留：

```text
Far
Mid
Near
```

但不要再让 Near 只占一条中间 lane。

---

## 4. 推荐 lane 参与方式

Compact Bar 继续使用 5 条主要 lane。

例如：

```text
lane 0
lane 1
lane 2
lane 3
lane 4
```

建议重新分配为：

### Far Layer
参与所有 5 条 lane：

```text
0 / 1 / 2 / 3 / 4
```

作用：
- 铺底
- 保证画面 everywhere 都有粒子
- 最均匀、最广覆盖

### Mid Layer
参与 4 条 lane：

```text
0 / 1 / 3 / 4
```

或：

```text
1 / 2 / 3 / 4
```

两种都可以，但推荐避开与 Near 完全重叠过多。
更推荐：

```text
1 / 2 / 3 / 4
```

如果实际更平衡，也可以让 mid 覆盖全部 5 条 lane，但不同 lane 数量不一样。

### Near Layer
不要只用中间一条。

改成参与 3 条 lane：

```text
1 / 2 / 3
```

也就是：

- 中间主 lane：2
- 中间上方 lane：1
- 中间下方 lane：3

这样最大粒子会分布在中间附近的 3 条 lane，而不是死锁在正中一条。

---

## 5. Near Layer 的 lane 权重

Near 仍然不能完全平均分配，否则会失去“主通道”感。

建议：

```text
lane 1 : lane 2 : lane 3
= 1 : 2 : 1
```

意思是：

- 最大粒子主要仍在中心 lane 2
- 但 lane 1 / 3 也明显会出现
- 视觉上会更丰满、更自然

例如 VeryFast 若 Near 共 12 个粒子，可分成：

```text
lane 1 = 3
lane 2 = 6
lane 3 = 3
```

而不是：

```text
lane 2 = 12
```

---

## 6. 粒子尺寸需要整体上调

当前用户已经明确觉得粒子偏小，所以尺寸需要整体抬高一点。

建议：

### Far Layer
当前偏小，建议改为：

```text
1.0 ~ 1.5 pt
```

不要再低到 `0.7 pt` 那么弱。

### Mid Layer
建议：

```text
1.6 ~ 2.3 pt
```

比现在更有存在感。

### Near Layer
建议：

```text
2.6 ~ 4.0 pt
```

其中少量 brightest near particle 可到：

```text
4.2 pt
```

但只允许极少数。

---

## 7. 亮粒子尺寸要有层次

Near Layer 内部也不要所有粒子一样大。

建议 Near 再细分：

### Near Normal
```text
2.6 ~ 3.2 pt
```

### Near Bright
```text
3.2 ~ 4.0 pt
```

### Near Highlight（极少数）
```text
3.8 ~ 4.2 pt
```

这样既有层次，又不会全部都太大。

---

## 8. Far / Mid / Near 数量建议

为了让“每一层更多更均匀”，建议总量略升，但按层分配合理。

### Slow
```text
Far:  18
Mid:  12
Near:  5
Total: 35
```

### Medium
```text
Far:  28
Mid:  20
Near:  7
Total: 55
```

### Fast
```text
Far:  40
Mid:  28
Near: 10
Total: 78
```

### VeryFast
```text
Far:  54
Mid:  36
Near: 14
Total: 104
```

这里：

- Far 最多
- Mid 次之
- Near 最少
- 但 Near 粒子更大、更快、更亮

注意：Far 粒子成本最低，不要让 Near 大量膨胀。

---

## 9. 每一层内部也要按 lane 分布均衡

不能再简单写成：

```text
Near 全塞 lane 2
```

每层自己的粒子 count 应按 lane 独立分配。

例如 VeryFast：

### Far 54
建议：

```text
lane 0 = 11
lane 1 = 11
lane 2 = 10
lane 3 = 11
lane 4 = 11
```

### Mid 36
建议：

```text
lane 1 = 9
lane 2 = 9
lane 3 = 9
lane 4 = 9
```

或如果使用 5 条 lane：

```text
lane 0 = 6
lane 1 = 7
lane 2 = 10
lane 3 = 7
lane 4 = 6
```

### Near 14
建议：

```text
lane 1 = 3
lane 2 = 8
lane 3 = 3
```

---

## 10. 每个 lane 都必须独立连续流

这个原则保留：

```text
每个 lane stream 必须自己均匀覆盖完整 0...1
```

不要再出现：

```text
这个 lane 现在刚好只有一侧有粒子
```

仍然使用：

```text
jittered stratified phase
```

但必须 per-lane 独立生成。

---

## 11. 不能只在中间给 halo

目前如果 halo 或 bright effect 只在最中间 lane 出现，也会放大“中线感”。

建议：

### Near Layer
lane 1 / 2 / 3 都允许 halo / sparkle。

但强度仍有权重差异：

```text
lane 2 最强
lane 1 / 3 略弱
```

例如：

```text
lane 1 / 3 halo strength = 0.85 × lane 2
```

这样不会显得上下两条是假粒子，中间那条才是真的主粒子。

---

## 12. Mid Layer 也应有少量更明显的粒子

如果 Mid 全都太弱，会导致视觉断层：

```text
Far 很弱
Near 很亮
中间层不够支撑
```

建议 Mid Layer 中也允许极少数 slightly brighter particles：

- 无明显 sparkle
- 可有极轻 halo 或更高 opacity
- 只占 mid 中的小部分

这样 near 不会显得孤零零悬在上面。

---

## 13. 右侧紫色仍然要保留并加强可见度

本轮虽然主要解决粒子分布，但不能丢掉你之前要求的右侧 activity 紫色区域。

继续保留：

```text
Purple Strength
Purple Coverage
```

并确保：

```text
activity 越高
→ 右侧紫色更强
→ 覆盖范围更左扩
```

同时粒子也轻微响应右侧紫色区域：

### Far
轻微或无 tint

### Mid
轻微 violet tint

### Near
更明显一些的 violet tint

---

## 14. 文字安全区仍然需要

中央：

```text
88% · 44%
```

仍然必须最清楚。

但不要为了避开文字而让中间 lane 几乎没有粒子。

正确做法：

- 所有层都可以经过中央
- Near 在文字核心区域略降亮度 / 降 sparkle
- Mid 在中心区域轻微降 opacity
- Far 基本正常通过

不要再把中央“清空”。

---

## 15. CPU 原则

虽然粒子会更多，但仍然必须控制开销。

原则：

### Far
- 最便宜
- 纯小圆点
- 无 halo

### Mid
- 大多数无 halo
- 少量轻微增强

### Near
- 少量高成本粒子
- halo / sparkle 只集中在这部分

仍然保持：

```text
一个 TimelineView
一个主 Canvas
```

不要增加多套刷新系统。

---

## 16. 推荐实现方式

建议从当前：

```text
Far / Mid / Near
```

进一步细化成：

```text
Far lane 0
Far lane 1
Far lane 2
Far lane 3
Far lane 4

Mid lane x...

Near lane 1
Near lane 2
Near lane 3
```

即：
- depth × lane
- 每个组合一个 stream descriptor
- 每个组合独立 count / phase / speed / tint / size range

这样可控性最高。

---

## 17. 验收标准

### 17.1 视觉
用户应明显感觉：

- 粒子比现在更大一点
- 上下空间更活了
- 最大粒子不只在中间一根线上跑
- 每层都更丰富、更均匀

### 17.2 不应出现
- 回到“一波一波”
- 粒子全挤到中间
- 上下两边只有稀疏陪衬
- 因为增大粒子而显得脏乱

---

## 18. 必须录屏

完成后请提供：

```text
slow 10 秒
medium 10 秒
fast 10 秒
veryFast 10 秒
```

并额外提供：

```text
隐藏文字后的 10 秒录屏
```

重点检查：

- largest particle 是否只在 lane 2
- lane 1 / 3 是否也有明显 near particle
- 每层是否足够均匀
- 上下区域是否比现在更丰富

---

## 19. 本轮不要修改

禁止：

```text
LocalTokenUsageMonitor
今日 Token 统计
TokenActivityPolicy threshold
Expanded UI
Compact 尺寸
app-server
JSON-RPC
业务逻辑
```

---

## 20. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 21. 最终汇报

完成后停止开发并汇报：

```text
1. Far / Mid / Near 各自参与哪些 lane
2. Near 是否从单 lane 改为 3 lanes
3. 各 activityLevel 的 far / mid / near count
4. 各 layer 的 size range
5. near bright / highlight size 是否提升
6. halo / sparkle 在 lane 1 / 2 / 3 如何分布
7. 右侧紫色是否仍生效
8. CPU 是否明显变化
9. build / tests / diff check
10. slow / medium / fast / veryFast 录屏
11. 隐藏文字后的录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_PARALLAX_DENSITY_BALANCE.md` 并严格执行。

当前问题：

```text
粒子整体偏小；
最大粒子几乎只在中间一条直线 lane 上显示；
每层粒子还不够丰富和均匀。
```

本轮目标：

```text
1. 整体粒子尺寸略增
2. Near Layer 从单 lane 扩展到 3 条 lane（1 / 2 / 3）
3. 每一层显示更多、更均匀的粒子
4. 保持三层景深
5. 保持连续流，不回到“一波一波”
6. 保持右侧紫色 activity accent
```

重点提醒：

```text
不要把 near 全塞中线。
最大粒子主要在中线，但上下相邻 lane 也要明显参与。
Far 要铺底，Mid 要支撑，Near 要点燃速度感。
```

不要修改业务逻辑。

# QuotaBar — Organic Particle Emitter Redesign

目标仓库：`xzcode/quota-bar`

本轮只解决两个核心问题：

```text
1. 粒子还是太少
2. 粒子看起来像固定一波一波出现，连位置都没有随机
```

当前用户反馈说明：之前的方案虽然尝试避免“乱”，但已经过度走向：

```text
过少
过整齐
过可预测
过像固定模板循环播放
```

本轮目标不是继续微调一点点，而是**把粒子流模型从“固定分布模板”改成“持续发射的有机粒子流（Organic Particle Emitter）”**。

---

## 1. 当前问题本质

当前视觉问题不只是“粒子少”。

真正的问题是：

### 1.1 粒子数量不足
画面中明显还能看到很多空区。

### 1.2 粒子位置像被写死
用户已经直接观察到：

```text
像是固定一波一波出现
连位置都没有随机
```

这意味着当前系统大概率仍然是：

- 一组固定 descriptor
- 一组固定 phase
- 固定速度
- 固定循环
- 时间一长，用户会看出 pattern

也就是说：

> 现在不是“自然流动”，而是“某个模板在循环平移”。

---

## 2. 本轮设计目标

新的目标是：

> **密集、连续、自然、非模板化、不会明显看出周期。**

用户最终感受应该是：

```text
粒子一直不断流过
位置有自然变化
每次看起来都不完全一样
但又不会乱成噪声
```

换句话说：

- 不是完全随机噪声
- 也不是固定队列死循环
- 而是“受控随机”的连续粒子流

---

## 3. 放弃“纯固定 phase 模板循环”

本轮不要再采用：

```text
预生成一组 phase
然后永远循环平移
```

哪怕 phase 本身用了 jittered stratified，也还是会有：

```text
固定图案
→ 平移
→ 回卷
→ 重复
```

时间稍长，用户一定会看出来。

---

## 4. 新模型：Per-Lane Organic Emitter

改成真正的：

```text
每条 lane 都是一个独立粒子发射器
```

结构：

```text
Far  lane 0 emitter
Far  lane 1 emitter
Far  lane 2 emitter
Far  lane 3 emitter
Far  lane 4 emitter

Mid  lane 1 emitter
Mid  lane 2 emitter
Mid  lane 3 emitter

Near lane 1 emitter
Near lane 2 emitter
Near lane 3 emitter
```

如果实现上想保守一点，也可以 lane 数略少，但核心原则必须保留：

> **每个 lane 都不是“固定模板循环”，而是“持续发射 / 回收 / 重排间距”。**

---

## 5. 每条 lane 的粒子模型

每条 lane 内维护一个有序粒子列表：

```text
particle[0], particle[1], particle[2], ...
```

每个粒子有：

```swift
id
x
speed
size
opacity
colorVariant
depthLayer
lane
isBright
sparklePhase
sparkleSpeed
sparkleDepth
```

运行中：

- 所有粒子向左移动
- 当某个粒子完全离开左边界
- 不要回到原来的固定 phase
- 而是回收到右边界外
- 插到“当前最右侧粒子”的后面
- 并重新分配一个**新的 gap**

这一点是本轮最关键改动。

---

## 6. 核心机制：Recycle Behind Rightmost

不要做：

```text
粒子离开左边
→ 回到固定 x
```

改成：

```text
粒子离开左边
→ 找到当前该 lane 最右边的粒子
→ 把离开的粒子放到它右边
→ 间距 = 一个新的随机 gap
```

即：

```text
...... A  B  C   ->   [D 离开左边]
回收后：
...... A  B  C       D
               <gap>
```

这样：
- 流是连续的
- 没有整批 reset
- 没有模板回卷感
- 分布会持续自然演化
- 但不会失控

---

## 7. Gap 必须“受控随机”

不要用固定 gap，也不要用完全自由随机 gap。

应该为每个 emitter 定义：

```text
minGap
maxGap
preferredGap
gapJitter
```

重新投放时：

```text
gap = preferredGap + boundedRandomOffset
```

例如：

```text
gap = preferredGap * (0.75 ~ 1.30)
```

并且要夹在：

```text
[minGap, maxGap]
```

之间。

这样可以保证：

- 不会太均匀
- 不会全挤一起
- 不会突然空一大片
- 但位置看起来会变

---

## 8. 推荐 gap 规则

### Far Layer
更密、更小：

```text
preferredGap:
7 ~ 11 pt

minGap:
4 ~ 6 pt

maxGap:
12 ~ 16 pt
```

### Mid Layer
中等：

```text
preferredGap:
10 ~ 15 pt

minGap:
6 ~ 8 pt

maxGap:
16 ~ 22 pt
```

### Near Layer
更稀一点，但更大：

```text
preferredGap:
16 ~ 24 pt

minGap:
10 ~ 12 pt

maxGap:
24 ~ 32 pt
```

这只是建议区间，需要按 210×32 的实际效果微调。

---

## 9. 每个 lane 需要自己的随机源

不要全局共享一个随机序列直接乱用。

建议每个 lane emitter 拥有独立 PRNG 状态：

```swift
struct LaneRNG { ... }
```

并在启动时用稳定 seed 初始化，例如：

```text
depth + lane + appLaunchSeed
```

这样：

- 每次应用启动后效果稳定自然
- 同一帧不会所有 lane 产生相似随机
- 粒子位置会持续演化
- 但不是每帧纯噪声

---

## 10. 允许“每次启动不同”

之前我们强调 deterministic，是为了避免跳变。

但这次用户明确觉得：

```text
位置都没有随机
```

所以本轮建议：

### 运行过程中
- 仍然保持连续平滑
- 不要每帧抖动

### 启动时
- 可以给整体 emitter 一个新的 session seed

也就是说：

```text
每次启动 App，粒子流 pattern 可以不同
```

但：

```text
同一次运行中，动画必须平滑连续
```

---

## 11. 三层仍然保留

Organic Emitter 不是取消三层，而是重做其流动方式。

继续保留：

### Far
- 最多
- 最小
- 最淡
- 最慢

### Mid
- 次多
- 中等大小
- 作为主流

### Near
- 最少
- 最大
- 最亮
- 最快

---

## 12. 粒子数量显著提升

用户已经明确觉得粒子太少。

本轮建议重新提高数量。

### Slow
```text
Far:  24
Mid:  14
Near:  6
Total: 44
```

### Medium
```text
Far:  36
Mid:  22
Near:  8
Total: 66
```

### Fast
```text
Far:  52
Mid:  32
Near: 12
Total: 96
```

### VeryFast
```text
Far:  68
Mid:  42
Near: 16
Total: 126
```

注意：
- Far 粒子便宜，可以多
- Near 粒子贵，控制数量
- 这个数量是“视觉粒子总量”，不是都要做高成本特效

---

## 13. 尺寸也要继续提升一点

当前用户仍然觉得粒子显得太弱。

建议：

### Far
```text
1.0 ~ 1.6 pt
```

### Mid
```text
1.6 ~ 2.5 pt
```

### Near
```text
2.8 ~ 4.4 pt
```

Near 的最亮少数粒子可到：

```text
4.6 pt
```

但只允许极少数。

---

## 14. Near 不要只在中线

这个之前已经提出，但这次要继续强调。

Near Layer 必须分布到：

```text
lane 1
lane 2
lane 3
```

权重建议：

```text
1 : 2 : 1
```

例如 Near = 16 时：

```text
lane 1 = 4
lane 2 = 8
lane 3 = 4
```

这样最大的粒子不再只在正中一条线跑。

---

## 15. Far / Mid 也要真正铺满

为了避免画面空：

### Far
建议覆盖 5 条 lane：

```text
0 / 1 / 2 / 3 / 4
```

### Mid
建议覆盖至少 3~5 条 lane：

推荐：

```text
1 / 2 / 3
```

或者：

```text
0 / 1 / 2 / 3 / 4
```

如果 CPU 扛得住，也可以让 Mid 全覆盖，但不同 lane 数量不同。

目标：
- 上下都有活跃感
- 不是中间独大、上下发呆

---

## 16. 不要整批“发射”

虽然叫 emitter，但不要理解为：

```text
一批一起刷出来
```

必须是：

- 每个粒子独立移动
- 每个粒子独立离开
- 每个粒子独立回收
- 每个粒子独立重新插到最右侧

所以看起来应该是：

```text
连续流
```

不是：

```text
脉冲流
```

---

## 17. 避免“重复图案”的两个额外技巧

除了随机 gap，再加两个技巧：

### 17.1 小范围速度漂移（per-emitter，不是 per-particle）
每个 emitter 保持固定速度，但不同 emitter 略不同：

例如：

```text
Far lane 0  0.58x
Far lane 1  0.61x
Far lane 2  0.64x
Far lane 3  0.60x
Far lane 4  0.57x

Mid lane 1  0.96x
Mid lane 2  1.00x
Mid lane 3  1.04x

Near lane 1 1.55x
Near lane 2 1.70x
Near lane 3 1.60x
```

这样不同 lane 之间会持续错位。

### 17.2 不同 emitter 使用不同 gap 区间
例如：

```text
Far lane 0 更密
Far lane 4 稍疏
Mid lane 2 稍密
Near lane 1 稍稀
```

这样整体不容易出现重复纹理。

---

## 18. Sparkle 继续只作用于 Near 为主

不要因为粒子更多，就让所有粒子都发光。

继续保持：

### Far
- 无 sparkle
- 无 halo

### Mid
- 绝大部分无 sparkle
- 少量稍亮，但不要明显闪

### Near
- halo
- sparkle
- brightest particles

---

## 19. 右侧紫色仍需保留

本轮虽然主要解决“数量少 + 固定一波一波”，但不要把紫色 activity accent 丢掉。

继续保留：

```text
Purple Coverage
Purple Strength
```

并确保：

```text
速度越快
→ 紫色更强
→ 覆盖范围更左扩
```

---

## 20. 粒子对右侧区域的响应

继续保留轻微 tint：

### Far
- 非常弱

### Mid
- 轻微 violet bias

### Near
- 更明显一点 violet bias

但不要所有粒子全紫化。

---

## 21. 文字安全区

中央：

```text
92% · 42%
```

依然要清楚。

但是不能为了文字安全区把中间清空。

正确做法：

- 粒子照常流过
- Near 在文字核心区降 sparkle
- Mid 轻微降 opacity
- Far 基本正常

不要出现“文字附近反而没粒子”的假感。

---

## 22. CPU 控制原则

虽然粒子数提高，但必须控制成本：

### Far
- 最便宜
- 小圆点
- 无 halo

### Mid
- 中等成本
- 少量亮度增强即可

### Near
- 最少
- 才承担 halo / sparkle

仍使用：

```text
一个 TimelineView
一个主 Canvas
```

不要为每层创建独立刷新系统。

---

## 23. 验收标准

### 必须达到
- 肉眼明显比现在粒子更多
- 粒子分布不再像固定模板循环
- 连续看 20 秒，不应出现“完全同样的图案又来了”
- 每层粒子都更丰富
- Near 粒子不只在中线
- 上下空间更活
- 整体更像持续不断的星尘数据流

### 不应出现
- 回到“一坨一坨”
- 全局随机噪声
- 粒子密到脏
- CPU 爆炸
- 粒子全都变成亮点

---

## 24. 必须录屏

完成后提供：

```text
slow 20 秒
medium 20 秒
fast 20 秒
veryFast 20 秒
```

并额外提供：

```text
隐藏百分比文字后的 20 秒录屏
```

重点观察：

- 是否仍然像固定模板循环
- 是否看得出明显重复 pattern
- 粒子数量是否明显增加
- Near 是否分布到 lane 1 / 2 / 3
- 上下是否明显更丰富

---

## 25. 本轮不要修改

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

## 26. Build / Tests

完成后：

```bash
swift build
swift run QuotaBarTests
git diff --check
```

---

## 27. 最终汇报

完成后停止开发并汇报：

```text
1. 是否从固定 phase 模板改成了 per-lane emitter
2. 回收逻辑是否采用 recycle-behind-rightmost
3. far / mid / near 数量
4. 各 layer / lane 的数量分配
5. gap 范围如何设置
6. 是否使用独立 lane RNG
7. 是否支持每次启动 pattern 略不同
8. near 是否覆盖 1 / 2 / 3 lanes
9. CPU 是否明显变化
10. build / tests / diff check
11. slow / medium / fast / veryFast 录屏
12. 隐藏文字后的录屏
```

---

# 给 Codex 的执行指令

阅读 `QUOTABAR_ORGANIC_PARTICLE_EMITTER.md` 并严格执行。

当前问题：

```text
粒子还是太少；
粒子看起来像固定一波一波出现；
连位置都没有随机。
```

本轮不要再继续沿用“固定 phase 模板循环”的思路。

直接改成：

```text
Per-Lane Organic Emitter
+
Recycle Behind Rightmost
+
Bounded Random Gap
```

并同时做到：

```text
1. 粒子总量明显提高
2. pattern 不再明显重复
3. Near 分布到 1 / 2 / 3 三条 lane
4. 保持 Far / Mid / Near 层次
5. 保持右侧紫色 activity accent
6. 不回到脉冲式一波一波
```

不要修改业务逻辑。

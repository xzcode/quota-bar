# QuotaBar — UI / Performance Polish Spec

目标仓库：`xzcode/quota-bar`  
本轮目标：只做收纳态视觉与性能打磨，并完成项目名称重命名。  
不要新增业务功能，不要改 Codex 额度协议，不要改 app-server / JSON-RPC 数据链路。

---

## 1. 本轮目标

当前功能已经基本完成，本轮只处理以下四类事项：

1. calm / 平稳状态下彻底停止动态特效，降低常驻功耗
2. 调整收纳态 Bar 尺寸：更短、更高
3. 项目统一重命名为 `QuotaBar`
4. active / fast / veryFast 状态下增强粒子与能量流视觉

---

## 2. Calm 状态必须完全静止

当 `BurnRateLevel == .calm` 时：

- 粒子停止运动
- 渐变停止流动
- 不维持 TimelineView 动画刷新
- 不做持续 brightness / opacity / phase 动画

目标：calm 状态下尽量接近零动画刷新，降低 CPU / GPU 常驻开销。

允许保留静态渐变背景、少量静态光点或静态高光；也可以完全不显示粒子，但视觉上仍应保持完整。

---

## 3. 动态帧率策略

不要继续让收纳态长期跑两个独立的 30 FPS TimelineView。

建议：

```text
calm:     0 FPS，完全静止
active:  10 ~ 12 FPS
fast:    16 ~ 18 FPS
veryFast:20 ~ 24 FPS
```

优先目标：粒子和渐变共享同一个时间源。

不要让 `CompactQuotaBar` 和 `ParticleFlowView` 各自维护一个独立 TimelineView。

---

## 4. Reduced Motion

继续支持：

```swift
@Environment(\.accessibilityReduceMotion)
```

如果系统开启 Reduce Motion：

- 所有粒子停止
- 所有渐变流动停止
- 不播放拖尾动画
- 展开 / 收起使用极短淡入淡出或无动画

额度显示本身不能受影响。

---

## 5. 收纳态尺寸调整

当前约：

```text
260 × 24
```

改为：

```text
240 × 28
```

目标是更短、更高、更像能量胶囊。

最终基准：

```swift
width = 240
height = 28
cornerRadius = 14
```

保持完整胶囊形。

---

## 6. 收纳态文字

继续保留双百分比：

```text
100% · 76%
```

不要改回单百分比。

建议：

```swift
.font(.system(size: 12, weight: .semibold, design: .rounded))
.monospacedDigit()
```

如果 28pt 高度下视觉略空，可以微调到 12 ~ 13 pt，但不要过大。

---

## 7. 收纳态视觉目标

收纳态应该像“一根安静但有生命感的能量胶囊”。

不要做成普通进度条、游戏血条、霓虹灯或星空。

- calm：静态、克制、有质感
- active / fast / veryFast：逐渐活起来

---

## 8. 粒子效果增强

只增强：

```text
active
fast
veryFast
```

calm 不播放动态粒子。

允许增加：

- 粒子大小差异
- 粒子速度差异
- 粒子亮度差异
- 轻微上下波动
- 少量拖尾
- 1 ~ 2 个更亮的能量粒子
- 轻微 glow
- 渐变流动更明显

---

## 9. 粒子视觉分层

建议把粒子分为三类。

### Background particles

- 小
- 淡
- 慢
- 数量较多

### Energy particles

- 稍大
- 更亮
- 速度更快
- 数量少，建议 1 ~ 2 个

### Trail particles

仅 fast / veryFast 使用：

- 短拖尾
- 低透明
- 不超过几个像素视觉长度

不要做长光束。

---

## 10. 粒子数量限制

总粒子数继续限制：

```text
<= 16
```

建议：

```text
active:   8 ~ 10
fast:    10 ~ 12
veryFast:12 ~ 14
```

不要因为“更酷炫”无限增加粒子。

---

## 11. 粒子速度

建议：

```text
active:   5 ~ 7 秒穿过 Bar
fast:     3 ~ 4.5 秒
veryFast: 1.8 ~ 3 秒
```

加入约 ±20% 个体差异。

不要让所有粒子同步移动。

---

## 12. 粒子轨迹

主方向：

```text
left → right
```

允许：

- 轻微上下波动
- 轻微正弦曲线
- 不同振幅

不要使用完全随机 Brownian motion、雪花下落、烟花、爆炸或旋涡。

整体仍然应该像“能量正在流动”。

---

## 13. Gradient 动效

- calm：完全静止
- active：非常轻微流动
- fast：明显但柔和
- veryFast：更明显，允许有轻微亮区扫过

不要高速闪烁、强烈 pulsate 或大面积 glow。

---

## 14. 颜色规则保持不变

不要修改现有 remaining state 逻辑：

```text
remaining > 25%  -> normal
11% ~ 25%        -> low
<= 10%           -> critical
```

不要修改现有 Burn Rate 阈值。本轮只调整视觉映射。

---

## 15. 项目名称统一改为 QuotaBar

当前旧名称：

```text
CodexQuotaMonitor
```

统一改为：

```text
QuotaBar
```

需要检查：

- Swift executable target
- Swift module / product
- `.app` bundle 名称
- Info.plist
- CFBundleDisplayName
- CFBundleName
- README
- package-app.sh
- 日志 subsystem
- 菜单标题
- 文档标题
- 构建命令
- 测试命令

最终期望：

```text
QuotaBar.app
swift run QuotaBar
```

---

## 16. 重命名兼容要求

不要因为重命名导致用户现有设置全部丢失。

现有 UserDefaults keys、cache keys、window position keys、burn rate history key 如果带旧名称但不影响功能，优先保持不变，避免用户升级后：

- 窗口位置丢失
- collapsed / expanded 状态丢失
- always-on-top 设置丢失
- burn rate 历史丢失

只有明确需要时才迁移 key。

---

## 17. 测试 Target

当前测试 target 已统一为：

```text
QuotaBarTests
```

---

## 18. 展开态不要大改

本轮不要修改：

- 5 小时额度
- 周额度
- 进度条
- 重置倒计时
- 消耗速度
- Footer

布局保持现状。

---

## 19. 右上角菜单

保持：

```text
⌃   ↻   ···
```

如果仍存在系统自动菜单箭头，隐藏 menu indicator。

不要出现：

```text
···⌄
```

---

## 20. 性能验收

目标：

```text
calm 状态下：
不应存在持续 10 / 20 / 30 FPS UI 刷新

active / fast / veryFast：
按等级使用低帧率动画
```

请实际观察 Activity Monitor 中的 CPU usage 和 Energy Impact。

不要求绝对数值，但 calm 状态应明显低于当前版本。

---

## 21. 视觉验收

Collapsed：

```text
240 × 28
```

检查：

- 深色桌面
- 浅色桌面
- 100% · 76%
- 低额度状态
- active
- fast
- veryFast

目标：

```text
calm 安静
active 有轻微流动
fast 明显活跃
veryFast 有能量流感
```

但不要刺眼、闪烁或游戏化。

---

## 22. 不允许做的事情

本轮禁止：

- 新增历史图表
- 新增通知系统
- 修改 Burn Rate 阈值
- 修改额度协议
- 修改 Reserve fallback
- 修改 app-server 通信
- 修改 JSON-RPC 结构
- 新增第三方动画库
- 引入 SpriteKit
- 引入 Metal
- 引入大型依赖
- 重新设计展开态布局

---

## 23. 建议实现顺序

### Step 1

先完成项目重命名：

```text
CodexQuotaMonitor
→ QuotaBar
```

保证：

```bash
swift build
```

通过。

### Step 2

调整 collapsed size：

```text
240 × 28
```

确认拖动、展开、收起、位置保持正常。

### Step 3

实现 calm 完全静态。

确认没有持续 TimelineView 动画刷新。

### Step 4

合并动画时钟。

active / fast / veryFast 使用统一时间源。

### Step 5

增强粒子视觉。

加入亮粒子、速度差异、轻拖尾、上下波动、渐变能量流。

---

## 24. 最终验收命令

```bash
swift build
swift run QuotaBar
swift run QuotaBarTests
git diff --check
```

---

## 25. 完成后汇报

完成后停止开发，不要继续加功能。

请汇报：

1. QuotaBar 重命名涉及哪些文件
2. UserDefaults / cache 是否保持兼容
3. collapsed 最终尺寸
4. calm 如何做到完全静止
5. 是否合并了 animation clock
6. active / fast / veryFast 各自刷新频率
7. 粒子视觉具体增强了什么
8. 是否使用拖尾
9. build 结果
10. tests 结果
11. git diff --check 结果
12. calm 状态下 Activity Monitor 的 CPU / Energy Impact 观察

---

## 26. 给 Codex 的执行指令

阅读 `QUOTABAR_UI_PERFORMANCE_POLISH.md` 并严格执行。

本轮只做：

```text
项目重命名
收纳态尺寸调整
calm 静态化
动态帧率优化
粒子视觉增强
```

不要修改业务逻辑，不要修改额度协议，不要继续新增功能。

完成全部事项后运行 build / tests / diff check，并停止开发，汇报结果。

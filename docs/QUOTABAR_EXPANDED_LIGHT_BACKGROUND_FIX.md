# QuotaBar — Expanded Card Light-Background Visual Fix

目标仓库：`xzcode/quota-bar`  
当前目标：修复 **白色 / 浅色桌面背景下，Expanded 卡片发灰、发虚、文字对比度不足** 的问题。

本轮只处理 **Expanded 卡片容器与视觉层**。

不要修改：

- Codex app-server
- JSON-RPC
- 额度解析
- Burn Rate 算法
- Token 统计逻辑
- Reserve fallback
- Collapsed Energy Bar
- 展开 / 收起交互
- 窗口持久化
- RefreshScheduler

---

## 1. 当前问题

浅色桌面背景下，Expanded 卡片会出现：

1. 整体背景过浅
2. 卡片与桌面边界不清楚
3. secondary text 对比度太低
4. progress track 过灰
5. footer 看起来像 disabled
6. 卡片失去“悬浮监控面板”的感觉

目标不是做“浅色版卡片”，而是：

> **无论桌面背景是浅色还是深色，QuotaBar Expanded 都保持稳定的深色能量卡片视觉。**

---

## 2. Expanded 固定深色视觉

不要再让卡片外观强依赖桌面背景或系统 Material 的自动浅化。

建议使用固定深色基底：

```text
#111317
~
#151821
```

允许加入非常轻的蓝紫冷色偏移。

例如：

```text
top-left:
#151A24

center:
#12151B

bottom-right:
#181421
```

整体仍然接近深灰黑，不要做成紫色大色块。

---

## 3. 背景结构建议

Expanded 背景建议分层：

```text
Dark Base
+
Very Subtle Blue Glow
+
Very Subtle Violet Glow
+
Top Inner Highlight
+
Outer Border
+
Inner Border
+
Shadow
```

不要只用一个：

```swift
.ultraThinMaterial
```

解决所有视觉问题。

---

## 4. Material 使用

如果继续保留 Material：

建议：

```text
dark base
+
material overlay
```

而不是：

```text
material 直接作为唯一背景
```

例如思路：

```swift
RoundedRectangle(...)
    .fill(Color(...))
    .overlay(.ultraThinMaterial.opacity(...))
```

或者等价实现。

目标：

- 保留一点玻璃质感
- 但整体亮度由我们自己控制
- 不允许浅色桌面把卡片染成发白灰色

---

## 5. 主背景颜色

建议基底接近：

```swift
Color(red: 0.07, green: 0.08, blue: 0.10)
```

或：

```text
#121419
```

允许轻微透明，但不要低到能明显看到白背景透进来。

建议整体 opacity：

```text
0.92 ~ 0.97
```

---

## 6. 蓝紫冷光

左上可加极淡蓝色 glow：

```text
opacity 0.05 ~ 0.10
blur 20 ~ 32
```

右下可加极淡紫色 glow：

```text
opacity 0.04 ~ 0.08
blur 20 ~ 32
```

目的：

```text
和 Compact Energy Bar 保持同一视觉语言
```

不是做明显彩色背景。

---

## 7. 外阴影

白色背景下，阴影必须增强。

建议：

```text
opacity: 0.22 ~ 0.30
radius: 16 ~ 24
y: 8 ~ 12
```

不要太重，不要像弹窗。

目标：

```text
让卡片明确悬浮于桌面之上
```

---

## 8. 外描边

增加外层 1px 描边：

```text
white.opacity(0.08 ~ 0.12)
```

或者：

```text
blue-violet low-opacity gradient
```

但必须非常克制。

---

## 9. 内描边 / 内高光

再增加一层轻微内高光：

```text
white.opacity(0.03 ~ 0.05)
```

用于增强玻璃边缘。

不要形成双线框的明显视觉。

---

## 10. 文字层级

白色背景下 secondary text 当前太淡。

请明确设置 Expanded 卡片里的文字颜色，不要完全依赖 `.secondary`。

### 主标题 / 主百分比

例如：

```text
Codex
96% 剩余
63% 剩余
```

建议：

```text
white.opacity(0.95 ~ 1.00)
```

### 次级说明

例如：

```text
4 小时 27 分后重置
3 天 11 小时后重置
```

建议：

```text
white.opacity(0.58 ~ 0.68)
```

### 弱提示

例如：

```text
刚刚更新
消耗速度：平稳
```

建议：

```text
white.opacity(0.42 ~ 0.52)
```

不要低于这个范围。

---

## 11. Status Footer

当前：

```text
● 正常                      刚刚更新
```

建议：

- 绿色状态点继续保持清晰
- `正常` 使用中高亮度文字
- `刚刚更新` 使用中等灰白

建议：

```text
正常:
white.opacity(0.70 ~ 0.80)

刚刚更新:
white.opacity(0.45 ~ 0.55)
```

---

## 12. Progress Track

当前在浅色背景下轨道容易显得灰白发虚。

Expanded 轨道建议固定：

```text
white.opacity(0.10 ~ 0.14)
```

不要跟随系统浅色动态变化。

---

## 13. Progress Fill

进度条填充继续保留现有颜色逻辑。

normal：

```text
blue → violet
```

low / critical：

保持现有危险色策略。

不要因为本轮背景修改重做 progress 的业务颜色映射。

---

## 14. Header Icons

右上：

```text
⌃   ↻   ···
```

建议统一：

```text
white.opacity(0.70 ~ 0.82)
```

hover：

```text
white.opacity(1.0)
```

不要在浅色桌面下自动变成浅灰。

---

## 15. “消耗速度”行

例如：

```text
消耗速度：平稳
```

建议比 reset text 略弱，但不要像 disabled。

建议：

```text
white.opacity(0.48 ~ 0.58)
```

如果前面有小图标，也保持同一层级。

---

## 16. Expanded 固定 dark appearance

如果当前 `NSHostingView` / SwiftUI View 会受系统 Appearance 影响：

建议让 QuotaBar widget panel 固定使用 dark visual appearance。

例如：

```text
preferredColorScheme(.dark)
```

但不要只依赖它。

即使 dark scheme，背景本身仍应使用固定自定义深色层。

---

## 17. 白色桌面验收标准

必须使用真正白色 / 接近纯白背景测试。

要求：

- 卡片边界清楚
- 文字完全可读
- reset text 不发灰到看不见
- progress track 可辨认
- footer 不像 disabled
- 卡片明显悬浮于桌面
- 仍然保持克制，不像普通 modal dialog

---

## 18. 深色桌面验收标准

修改后不能破坏现有深色背景效果。

要求：

- 不出现过重黑块
- 阴影不能过重
- 蓝紫冷光保持轻微
- 卡片不应像纯黑矩形
- 与 Compact Energy Bar 视觉统一

---

## 19. 不允许做的事情

本轮禁止：

```text
重做 Expanded 布局
调整 5h / 周额度结构
增加新统计项
修改 Burn Rate
修改 Token usage
修改 Compact Energy Bar
修改窗口尺寸
修改 app-server
修改 JSON-RPC
新增第三方库
```

---

## 20. 推荐实现顺序

### Step 1

移除或弱化 Expanded 对 `.ultraThinMaterial` 的直接依赖。

### Step 2

加入固定深色 base。

### Step 3

加入轻微蓝紫 glow。

### Step 4

调整：

```text
shadow
border
inner highlight
```

### Step 5

逐项设置 Expanded 文字层级颜色。

### Step 6

调整 progress track。

### Step 7

在：

```text
纯白桌面
浅灰桌面
深灰桌面
黑色桌面
```

下分别截图验收。

---

## 21. Build / Tests

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

## 22. 最终汇报

完成后停止开发。

请汇报：

```text
1. Expanded 背景最终结构
2. 基础背景颜色
3. Material 是否继续使用
4. shadow 参数
5. border 参数
6. 主文字颜色层级
7. secondary text 颜色层级
8. progress track 参数
9. 白色桌面截图
10. 深色桌面截图
11. build 结果
12. tests 结果
13. git diff --check 结果
```

---

## 23. 给 Codex 的执行指令

阅读 `QUOTABAR_EXPANDED_LIGHT_BACKGROUND_FIX.md` 并严格执行。

本轮只修复：

```text
Expanded 卡片在白色 / 浅色桌面背景下发灰、发虚、对比度不足的问题
```

核心要求：

```text
Expanded 固定深色能量卡片
不要让桌面背景把卡片染浅
增强卡片边界与文字可读性
保留玻璃质感
保持深色桌面效果
```

不要修改业务逻辑和数据逻辑。

完成后提供白色桌面与深色桌面对比截图，并停止开发。

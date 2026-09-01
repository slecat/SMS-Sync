# 验证码转发过滤设计

**日期：** 2026-03-22

**目标：** 在桌面端和移动端各增加一个“只转发验证码消息”设置项，默认关闭；移动端负责源头过滤，桌面端负责展示与提醒兜底过滤。

## 背景

当前移动端会将收到的短信同步到其他设备，桌面端会展示短信并触发强提醒。用户希望在需要时只处理验证码短信，避免普通短信同步和提醒带来干扰。

仓库现状：

- 移动端是主要发送端，短信发送路径集中在 `sms-sync/mobile/lib/background/background_runtime.dart` 和 `sms-sync/mobile/lib/ui/home/home_action_coordinator.dart`。
- 桌面端是主要接收端，短信展示与提醒入口集中在 `sms-sync/desktop/main/app.js`。
- 移动端已有一套验证码识别规则，当前位于 `sms-sync/mobile/lib/ui/home/home_view_state.dart`。
- 桌面端已有验证码提取逻辑，当前位于 `sms-sync/desktop/main/services/message-utils.js`，但规则较宽松。

## 需求确认

- 桌面端设置项语义：只显示/提醒验证码短信，不要求影响其他设备。
- 默认值：关闭，保持升级前行为不变。
- 移动端设置项语义：开启后只转发验证码短信，普通短信不再向其他设备同步。

## 方案对比

### 方案一：移动端发送前过滤，桌面端展示前过滤

移动端根据本地设置决定是否发送短信；桌面端根据本地设置决定是否展示和提醒。

优点：

- 与现有架构最贴合。
- 不修改消息协议，兼容旧版本客户端。
- 桌面端可以兜底拦住来自旧移动端或其他来源的普通短信。

缺点：

- 两端都需要维护验证码识别逻辑。

### 方案二：在消息协议中增加验证码标记字段

移动端为短信 payload 增加 `isVerificationCode` 字段，桌面端直接按字段过滤。

优点：

- 桌面端逻辑简单。

缺点：

- 需要修改协议和兼容逻辑。
- 旧版本消息没有该字段，需要额外兜底。

### 方案三：仅移动端过滤

只在移动端增加设置项，桌面端不参与过滤。

优点：

- 改动最小。

缺点：

- 桌面端设置项会名不副实。
- 无法处理其他来源或旧版本发来的普通短信。

## 最终方案

采用方案一。

### 行为定义

- 两端默认关闭该开关。
- 移动端开启后：
  - 后台自动转发路径仅发送验证码短信。
  - 手动“读取最新”路径也仅发送验证码短信。
- 桌面端开启后：
  - 仅验证码短信进入消息列表。
  - 仅验证码短信触发强提醒和复制验证码逻辑。
  - 普通短信直接忽略，不增加计数。

### 验证码识别规则

采用更保守的规则：

- 文本包含验证码相关关键词。
- 文本同时包含 4 到 8 位数字片段。

关键词示例：

- `验证码`
- `校验码`
- `动态码`
- `otp`
- `one-time`
- `verification code`
- `security code`

这样可以降低将物流单号、订单号、金额等普通数字误判为验证码的概率。

## 实现落点

### 移动端

- `sms-sync/mobile/lib/services/settings_repository.dart`
  - 为 `SyncSettings` 增加 `forwardVerificationCodeOnly`。
  - 读写该布尔值，默认 `false`。
- `sms-sync/mobile/lib/services/`
  - 新增验证码识别工具，供 UI 与后台复用。
- `sms-sync/mobile/lib/background/background_runtime.dart`
  - 在 `processIncomingSms(...)` 开头读取设置并执行过滤。
- `sms-sync/mobile/lib/ui/home/home_action_coordinator.dart`
  - 在“读取最新短信并发送”路径加同样过滤。
  - 手动读取遇到普通短信时返回“已跳过”的结果，避免误报“已发送”。
- `sms-sync/mobile/lib/ui/home/settings_tab.dart`
  - 新增开关 UI。
  - 切换后持久化设置，并通知后台服务重新加载配置。

### 桌面端

- `sms-sync/desktop/main/app.js`
  - 设置默认值、加载和保存逻辑增加 `forwardVerificationCodeOnly`。
  - 在 `handleSmsMessage(...)` 中按设置执行过滤。
- `sms-sync/desktop/main/services/message-utils.js`
  - 新增严格的 `isVerificationCodeMessage()`。
  - `extractVerificationCode()` 基于更严格的识别前提工作。
- `sms-sync/desktop/index.html`
  - 增加开关 UI。
- `sms-sync/desktop/renderer/app.js`
  - 加载、展示和保存新设置。

## 兼容性

- 不修改消息协议。
- 旧版本移动端仍可发送普通短信，但新版桌面端开启该选项后会自行拦截。
- 升级后默认行为不变，不会影响现有用户。

## 测试策略

### 自动化测试

- 移动端：
  - 验证码识别规则测试。
  - `SettingsRepository` 新字段读写测试。
  - “读取最新短信”在过滤开关开启时遇到普通短信会跳过发送的测试。
- 桌面端：
  - `isVerificationCodeMessage()` 和 `extractVerificationCode()` 测试。
  - 设置默认值与保存回读测试。

### 手工验证

- 两端默认关闭时，普通短信和验证码短信都保持现状。
- 只开启移动端时，普通短信不再同步到桌面端。
- 只开启桌面端时，普通短信到达桌面端后不展示、不提醒。
- 两端都开启时，只保留验证码短信链路和提醒。

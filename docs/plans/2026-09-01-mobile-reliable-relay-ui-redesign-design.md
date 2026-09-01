# Sms-Sync 移动端可靠中继与 UI 重构设计

## 背景

Sms-Sync 当前由 Flutter 后台 isolate 承担 WebSocket、UDP、消息队列刷新和大部分运行状态管理。Android 原生层已经有 `SmsReceiver`、通知监听兜底、前台服务插件、开机恢复和 watchdog，但最终交付仍依赖 Flutter 运行时与一次性 WebSocket 发送。现有服务端只把消息转发给当时在线的客户端，运行事件保存在内存中；桌面端收到消息后直接进入内存列表和通知流程，没有持久 Inbox 与交付 ACK。

这导致多个静默丢失窗口：

- 原生消息通过 MethodChannel 交给 Flutter 后，Flutter 进程可能在消息真正发出前死亡。
- 原生待处理队列采用“取出即删除、失败后重建”的方式，进程在两步之间死亡会丢失消息。
- WebSocket `sink.add` 只代表写入本地 socket，不代表服务端已经接收或持久化。
- 服务端在桌面离线时没有可恢复的交付队列，服务端重启也会清空内存状态。
- 桌面端没有“先落盘、后 ACK”的边界，重复补发与进程死亡无法可靠处理。
- 当前去重部分依赖进程内变量，进程重启后失效；同一短信的广播入口与通知入口可能产生重复。

同机运行的 `E:/File/MySoftword/billr` 已验证独立原生前台服务、`START_STICKY`、boot/package-replaced 恢复、watchdog 和通知监听重绑能够在目标设备上长期保活。本设计以该模式为保活基线，并进一步补齐 Sms-Sync 特有的端到端持久交付协议。

## 目标

- Flutter UI 进程被系统回收时，短信接收、落盘、发送和重试仍可继续。
- 手机、服务端或桌面端任一环节断网或重启后，未完成消息能够恢复并最终交付。
- 采用至少一次传输和端侧幂等，使用户可见结果达到恰好一次：不漏消息、不重复弹通知。
- 移动端 UI 完全重构为克制、安静、接近系统工具的视觉语言，消除渐变大卡片、泛滥强调色和模板化“AI 仪表盘”表达。
- UI 能准确区分权限、后台限制、服务器连接、队列积压和交付确认状态，不再显示假健康。
- 服务端与桌面端完成可靠协议所需的重构，并进行适度视觉统一。

## 非目标

- 不承诺应用在用户执行 Android“强行停止”后自行恢复；Android 明确禁止这种恢复，应用只能在下次用户启动时说明情况。
- 不做单一手机品牌的隐藏 API、反射调用或 ROM 专用常驻漏洞适配。
- 不把 UDP 升级为可靠传输协议；UDP 继续作为低延迟局域网快速通道。
- 本轮不引入端到端加密新协议。继续使用现有签名字段与同步密钥，服务端持久文件依赖主机访问控制；加密可作为独立安全升级。
- 不在本轮完全重写桌面端信息架构，也不改写统一打包入口。

## 设计原则

1. **先落盘，后执行。** 系统入口只负责形成完整消息、持久化和安排工作。
2. **ACK 代表持久化，而非接收到 socket 数据。** 每一跳都必须在事务提交后确认。
3. **重试是正常路径。** 网络闪断、进程死亡和 ACK 丢失不能依赖异常补丁处理。
4. **稳定 ID 贯穿全链路。** 手机、服务端和桌面端对同一 `messageId` 执行幂等操作。
5. **保活与可靠交付解耦。** 原生常驻服务提高实时性，持久队列与系统调度保证恢复性。
6. **健康状态来自事实。** “正在守护”必须同时满足接收入口、原生服务、权限和队列状态要求。

## 总体架构

```text
Android SMS_RECEIVED / 通知监听兜底
                 |
                 v
        Native SMS Ingestor
     (multipart 合并、持久去重)
                 |
                 v
       Room Outbox 事务落盘
                 |
       +---------+---------+
       |                   |
       v                   v
Native Foreground      WorkManager
Relay Service          Recovery Worker
       |                   |
       +---------+---------+
                 |
                 v
       WebSocket Protocol v2
                 |
                 v
        Server SQLite Inbox
       (提交后返回 server-ack)
                 |
                 v
       Per-device Deliveries
                 |
                 v
      Desktop Persistent Inbox
       (提交后返回 delivery-ack)
                 |
                 v
       通知 / 验证码 / UI 展示
```

Flutter 只作为原生状态和配置的 UI 客户端，不再拥有短信交付生命线。移动端原生服务与 WorkManager 消费同一个 Room Outbox，并通过数据库租约避免并发重复发送。

## 移动端原生组件

### `SmsRelayForegroundService`

新增独立 Android 原生前台服务，参考 `billr` 的 `PaymentMonitorForegroundService`：

- `onStartCommand` 返回 `START_STICKY`。
- 启动时立即创建低打扰、不可滑除的常驻通知。
- 维护 WebSocket v2 连接、心跳和 Outbox 消费循环。
- 服务重建时从原生数据库恢复，不依赖 Flutter 配置加载完成。
- `onDestroy` 不删除未确认消息；watchdog 负责在允许条件下重新拉起。

现有 `flutter_background_service` 不再承担可靠传输。迁移完成后移除其后台运行职责和仓库内对应定制依赖；Flutter 应用本身仍保持普通前台 UI 生命周期。

### 原生配置仓库

服务器地址、设备组、设备名、设备 ID、同步密钥和验证码过滤设置迁移到原生可读配置仓库。Flutter 通过 MethodChannel 调用原生仓库读写；升级时从现有 `FlutterSharedPreferences` 一次性导入并保留原值。

配置写入必须原子完成。服务器地址或同步密钥变化后，原生服务关闭旧连接、重新注册，并保留所有未确认 Outbox 项。

### 原生短信摄取

`SmsReceiver` 使用 `goAsync()`，在 Android 广播允许的短时间内完成：

1. 校验 `SMS_RECEIVED` action。
2. 按 format 解析全部 PDU，并按发送方与短信元数据合并 multipart 内容。
3. 生成持久 UUID `messageId`。
4. 计算规范化内容指纹，用于识别广播入口与通知监听入口的同一条短信。
5. 在一个 Room 事务中写入消息和去重指纹。
6. 请求原生前台服务消费；若系统不允许即时启动，则安排唯一 WorkManager 工作。
7. 调用 `PendingResult.finish()`。

通知监听继续作为兜底入口。它复用同一个摄取仓库，因此跨入口、跨进程去重，不再使用静态 `lastSignature`。

### 保活编排

保留并收敛现有 `BootReceiver`、`SmsKeepAliveHelper` 和 app-level watchdog：

- 响应 `BOOT_COMPLETED`、`MY_PACKAGE_REPLACED`、`QUICKBOOT_POWERON` 与 `USER_UNLOCKED`。
- 尊重用户显式停止与配置禁用状态。
- watchdog 检查新的原生前台服务，并在服务仍存活时继续检查通知监听绑定状态。
- 通知监听 `onListenerDisconnected()` 主动 `requestRebind()`。
- 原生服务、系统 Worker 和广播入口均记录结构化原因码，便于诊断。

watchdog 只提高恢复速度，不作为消息可靠性的唯一保证。WorkManager 与持久 Outbox 必须能够在 watchdog 延迟或闹钟受限时独立恢复。

## 移动端数据模型

### `outbox_messages`

| 字段 | 含义 |
| --- | --- |
| `message_id` | 客户端生成的 UUID，主键 |
| `fingerprint` | 规范化发送方、正文和时间窗口形成的去重指纹 |
| `sender` | 短信发送方 |
| `body` | 合并后的完整正文 |
| `received_at` | 系统短信时间 |
| `captured_at` | 本应用持久化时间 |
| `source` | `sms_receiver` 或 `notification_listener` |
| `state` | `pending`、`sending`、`retry_wait`、`server_acked`、`blocked` |
| `attempt_count` | 已尝试次数 |
| `next_attempt_at` | 下一次允许发送时间 |
| `lease_until` | 防止服务和 Worker 并发消费的租约时间 |
| `last_error_code` | 可展示、可聚合的稳定错误码 |
| `server_acked_at` | 服务端持久化确认时间 |

### `ingest_fingerprints`

保存短期去重指纹和首次对应的 `messageId`。默认窗口为 30 秒，记录保留 24 小时后清理。只有发送方、规范化正文和时间窗口均一致才视为同一候选，避免长期误杀内容相同的真实短信。

## 消息状态机与重试

```text
received -> pending -> sending -> server_acked
                 |         |
                 +<- retry_wait
                 |
                 +-> blocked
```

- 数据库写入成功即进入 `pending`。
- 消费者通过事务租约把项目切为 `sending`。
- 收到匹配 `messageId` 的 `server-ack` 后进入 `server_acked`。
- 网络、超时或服务器暂时错误进入 `retry_wait`。
- 配置缺失、同步密钥缺失或权限受损进入 `blocked`，并在条件修复后回到 `pending`。
- 服务或进程死亡后，过期租约自动回收到 `retry_wait`。

退避序列为 2 秒、5 秒、15 秒、1 分钟、5 分钟、15 分钟，之后以 30 分钟封顶并持续重试。网络恢复、服务启动、设备解锁、配置修复或 WebSocket 重连会把符合条件的任务立即唤醒。

未收到服务端 ACK 的消息不自动删除。达到 10,000 条或数据库 100 MB 的警戒线时，UI 与常驻通知进入明确的“积压需要处理”状态，但仍继续接收和重试。`server_acked` 正文在手机保留 7 天用于诊断，之后清理正文并保留聚合统计。

## 协议 v2

### 注册

客户端注册载荷增加：

- `protocolVersion: 2`
- `platform: mobile | desktop`
- `capabilities: [server-ack, delivery-ack, replay]`
- 稳定 `deviceId`、`groupId`、设备名与现有签名字段。

服务端回复 `registered`，包含协商后的版本、服务器时间和该设备待处理交付数。

### 手机到服务端

`sms` 载荷必须包含 `protocolVersion`、`messageId`、`sourceDeviceId`、`groupId`、`from`、`body`、`receivedAt` 与签名字段。服务端在同一 SQLite 事务中：

1. 以 `groupId + messageId` 幂等写入 `messages`。
2. 为已知桌面目标建立或确认 `deliveries`。
3. 提交事务。
4. 返回 `{ type: "server-ack", messageId, persistedAt }`。

重复上传返回同一个语义 ACK，不创建重复消息。

### 服务端到桌面端

服务端为在线桌面发送带 `deliveryId` 的 `delivery`。桌面端把消息写入本地 Inbox 后返回 `{ type: "delivery-ack", deliveryId, messageId, persistedAt }`。服务端幂等更新对应交付记录。

桌面重连后，服务端按 `createdAt + deliveryId` 顺序持续推送未确认项。单条 ACK 超时会重发；同一个桌面连接限制在固定数量的 in-flight 项，避免大量积压压垮渲染进程。

### 旧协议兼容

服务端在一个发布周期内同时接受 v1 与 v2。v1 继续即时转发但不声称可靠交付；v2 客户端只使用持久协议。服务端管理页分别统计 legacy 与 reliable 流量，待所有正式客户端升级后移除 v1。

## 服务端持久中继

服务端新增 SQLite 数据库，至少包含：

- `devices`：稳定设备、平台、设备组、最后上线时间和协议能力。
- `messages`：手机上行消息，唯一约束为 `group_id + message_id`。
- `deliveries`：每条消息到每台目标桌面的状态、尝试次数和 ACK 时间。
- `system_events`：结构化运行事件与错误码，不存储无限日志正文。

服务端当前内存 `relay-store` 保留在线 socket 索引和短期运行统计，但不再是消息事实来源。管理 API 从 SQLite 聚合可靠交付状态。

目标设备规则：消息入库时为同组内已登记的桌面设备创建交付项；如果组内尚无已登记桌面，消息保持 `unassigned`，第一台登记到该组的桌面会获得仍未过期的未分配消息。新加入的第二台桌面默认不回放加入前已经完成的历史消息。

未确认消息不按时间自动删除。全部交付确认后正文默认保留 7 天，再由维护任务清理正文和签名，仅保留交付统计。数据库每日执行备份与完整性检查；磁盘和最老积压时间进入管理页健康指标。

## 桌面端 Inbox 与 ACK

Electron 主进程新增持久 Inbox；渲染进程仍只通过 preload 暴露的安全 IPC 读取消息。处理顺序固定为：

1. 校验签名和消息结构。
2. 以 `messageId` 幂等写入 Inbox。
3. 提交本地持久化。
4. 返回 `delivery-ack`。
5. 首次插入时才触发验证码提取、系统通知和渲染事件。

桌面进程重启后从 Inbox 恢复最近记录。服务器重复投递同一消息时只重复 ACK，不重复弹通知。

桌面端保持现有功能结构，只做两类视觉调整：复用移动端暖灰、墨绿、边框和文字层级令牌；移除蓝色渐变与模板化彩色卡片。新增交付健康、积压数量和最近 ACK 状态，但不进行与可靠协议无关的页面重排。

## 移动端 UI 设计

### 视觉系统

采用已确认的“安静的原生工具”方向：

- 暖灰背景、深墨绿主状态、低饱和辅助色。
- 单一主强调色；警告和错误只在确有异常时出现。
- 克制圆角、清晰边框、极少阴影；不使用玻璃拟态、霓虹渐变、装饰性光晕和 emoji 图标。
- 优先平台字体与清晰数字，不额外加载网络字体。
- 动画只用于状态过渡，持续 150–250 ms，并尊重系统减少动态效果设置。
- 状态同时使用文字、图标和颜色，普通正文对比度达到 WCAG AA。
- Flutter 交互控件添加 `Semantics`，TalkBack 能读出状态、操作和错误恢复方式。

### 导航与页面

底部导航固定为三个入口：`同步`、`记录`、`设置`。

#### 同步

首页只回答“当前是否可靠同步”：

- 一个主健康状态：正在守护、需要设置、正在重试或同步受阻。
- 今日已送达与等待重试两个指标。
- 最近活动摘要。
- 异常时主状态区直接提供对应恢复动作，不要求用户自行判断设置入口。

首页移除手动“发送测试”和“读取最新短信”作为并列大按钮。测试能力移动到诊断页，避免主要界面看起来像开发工具。

#### 记录

默认列表展示发送方、摘要、时间和最终状态。详情页展示手机接收、服务端持久 ACK、桌面持久 ACK 和重试原因的时间线。正文显示遵循现有隐私习惯，诊断导出默认脱敏。

#### 可靠性设置向导

首次启动或健康条件受损时展示分步向导：短信权限、通知权限、后台无限制、通知访问兜底。每一步单独解释用途、当前状态和系统跳转，不连续弹出多个权限对话框。

#### 设置与诊断

服务器、设备组、设备名和同步密钥收纳到“连接”；可靠性检查、队列状态和脱敏日志收纳到“运行”；更新与版本信息收纳到“应用”。低频配置不再占独立底部 Tab。

## 健康状态计算

UI 不直接把 WebSocket `connected` 映射为“运行正常”。综合健康状态由原生层计算：

- `healthy`：必要权限满足、接收器可用、原生服务处于期望状态、最近心跳正常、无超龄积压。
- `degraded`：仍可接收并落盘，但网络断开、通知兜底未授权或存在短期积压。
- `blocked`：短信权限缺失、配置不完整、后台被限制或数据库不可写。
- `recovering`：服务刚恢复、正在重连或正在处理历史积压。

每个非健康状态必须包含稳定原因码和一个明确的下一步操作。Flutter 只渲染原生健康快照，不自行推断后台状态。

## 错误处理与可观测性

- 移动端、服务端和桌面端统一使用错误码，例如 `network_unavailable`、`server_ack_timeout`、`signature_invalid`、`storage_write_failed`、`background_restricted`。
- 原生日志使用结构化字段记录 `messageId` 的短哈希、状态转换、尝试次数和原因，不记录完整短信正文。
- 诊断导出包含环境、权限、服务状态、队列计数、最近状态转换和版本号；电话号码与正文默认脱敏。
- 服务端管理页展示待交付、重试中、已确认、最老积压、数据库大小和磁盘状态。
- 数据库写入失败不得返回 ACK；消息保持在上一跳并继续重试。

## 迁移与发布顺序

1. 部署同时支持 v1/v2 与 SQLite 的服务端，并验证旧客户端仍能连接。
2. 发布带持久 Inbox、ACK 和 replay 的桌面端。
3. 发布带原生 Outbox 与原生前台服务的移动端。
4. 观察一个正式版本周期，确认 reliable 流量、积压和 ACK 指标正常。
5. 移除旧 Flutter 后台交付路径和 v1 服务端转发入口。

移动升级首次运行时：

- 原子迁移现有 SharedPreferences 配置。
- 保留现有稳定 `deviceId`，避免服务端把升级后的手机识别为新设备。
- 初始化 Room 数据库。
- 启动可靠性检查向导，但已经满足的权限不重复请求。
- 现有原生 pending JSON 队列若存在，导入 Room 后才删除原值。

## 测试策略

### Android/Kotlin

- multipart PDU 合并和异常 PDU 容错。
- 广播入口与通知入口的持久去重。
- Outbox 状态转换、租约过期回收和退避序列。
- 配置迁移和旧 pending JSON 队列迁移。
- ACK 匹配、重复 ACK、超时与乱序 ACK。
- boot action、手动停止、watchdog 与通知监听重绑策略。

### Flutter

- 健康快照到页面状态的映射。
- 三个主导航页面和可靠性向导的 widget 测试。
- 状态不只依赖颜色，关键控件具备 Semantics。
- 设置通过 MethodChannel 原子写入原生仓库。

### 服务端

- 事务提交后才返回 `server-ack`。
- 重复 `groupId + messageId` 只生成一条消息。
- 服务端进程重启后恢复待交付项。
- 桌面离线、重连、ACK 超时、重复 ACK 和多设备目标规则。
- v1/v2 并存与协议协商。
- SQLite 迁移、备份和磁盘写入失败行为。

### 桌面端

- Inbox 提交后才发送 `delivery-ack`。
- 重复投递只通知一次。
- 进程重启后恢复记录并继续 ACK。
- 签名无效的消息不落盘、不 ACK。

### 实机与端到端

在 Android 16 实机执行：

- Flutter UI 退出和进程被系统回收。
- 原生服务被杀后 watchdog/系统调度恢复。
- 飞行模式、网络切换和长时间锁屏。
- 服务端重启和数据库恢复。
- 桌面端离线数小时后上线补发。
- 手机 ACK、桌面 ACK 分别丢失时的重复发送。
- 开机、应用升级和通知监听断开重绑。

每轮用唯一消息 ID 对账，最终所有测试消息必须进入 `desktop_acked`，且桌面通知计数与唯一消息数一致。

## 部署要求

服务端变更必须沿用 `sms-sync/server/deploy.sh` 与仓库现有 SSH/PM2 流程同步到实际服务器。部署前备份数据库目录，部署后验证：

- PM2 进程健康。
- v1 客户端仍可连接。
- v2 手机能收到提交后 ACK。
- 桌面离线消息能在重连后补发并完成 ACK。
- 进程重启后未确认交付仍存在。

移动端与桌面端继续统一通过 `sms-sync/package_all.bat` 打包，不另建根级打包入口。

## 完成标准

- 所有自动化测试通过，Flutter analyze、Flutter test、Android unit test、Desktop lint/test、Server test 无新增错误。
- Flutter UI 死亡不影响短信落盘和后续交付。
- 手机、服务端、桌面端任一单点重启后未确认消息可恢复。
- 断网和 ACK 丢失不会造成消息丢失或重复桌面通知。
- UI 准确展示权限、后台限制、连接和积压状态。
- 移动端完成已确认的 A 视觉方向，关键页面通过 375 px 宽度、文字缩放和 TalkBack 检查。
- 服务端实际完成部署与端到端验证，而非仅停留在本地代码。

## 已接受的取舍

- 为可靠性接受低打扰常驻通知、首次可靠性设置向导和更高的后台资源消耗。
- 为根治消息丢失接受移动端、服务端和桌面端的协议级重构。
- 使用至少一次传输与幂等去重，而不是依赖不可能由分布式网络保证的单次发送。
- 用户强行停止和系统“受限制”状态必须由用户恢复；产品负责检测、解释并提供直达入口，不伪装成仍在守护。

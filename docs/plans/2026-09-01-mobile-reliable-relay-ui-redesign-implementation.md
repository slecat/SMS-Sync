# Sms-Sync 移动端可靠中继与 UI 重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将短信同步升级为由 Android 原生持久队列驱动、服务端可恢复、桌面端 ACK 闭环的可靠中继，并完成移动端 A 方向 UI 重构。

**架构：** Android 原生 `SmsReceiver`/通知监听器先将短信写入 Room Outbox；`START_STICKY` 原生前台服务与 WorkManager 共同消费 Outbox，通过 WebSocket v2 发送并等待服务端持久 ACK。服务端 SQLite 保存 Inbox 与每个桌面设备的 Delivery，桌面端先写本地 Inbox 后 ACK。Flutter 变成原生状态与配置的 UI 客户端，移动端页面采用暖灰、墨绿、低装饰的“安静原生工具”方向。

**技术栈：** Kotlin Android（Room、WorkManager、Foreground Service、BroadcastReceiver、NotificationListenerService）、Flutter/Dart（Material 3、MethodChannel、Widget tests）、Node.js（ws、Express、SQLite）、Electron（主进程持久 Inbox、安全 IPC）、JUnit、Dart test、Node test。

## 当前实施进度（2026-09-01）

- 已完成：v2 协议校验、Android Room Outbox、multipart/跨入口去重、短信广播与通知监听的先落盘、原生 `START_STICKY` 中继、OkHttp WebSocket ACK 发送、WorkManager 租约恢复。
- 已完成：服务端事件快照持久化、server-ack/delivery-ack 闭环、桌面端 Inbox 落盘；移动端 A 方向暖灰/墨绿 UI 首版。
- 验证：Android 原生定向测试、Flutter 全量测试、Node 服务端全量测试、桌面端全量测试均通过；Flutter analyze 仅保留仓库内第三方依赖的既有 lint 提示。
- 后续增强：补齐设置/诊断原生桥接、Outbox 清理策略及真机长时间保活压测；服务端 replay 已支持最近 100 条短信。

---

## 变更文件与职责

### 移动端 Android

- 修改：`sms-sync/mobile/android/settings.gradle.kts`、`sms-sync/mobile/android/app/build.gradle.kts` —— 引入 Room、WorkManager 与 KAPT 依赖。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/storage/OutboxDatabase.kt` —— Room 数据库、实体、迁移版本。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/storage/OutboxDao.kt` —— Outbox 与去重指纹的原子读写、租约和状态转换。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/storage/OutboxRepository.kt` —— 摄取、领取、ACK、重试和迁移接口。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/ingest/SmsIngestor.kt` —— multipart 合并、稳定 ID、跨入口去重。
- 修改：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsReceiver.kt`、`SmsNotificationListenerService.kt` —— 使用 `goAsync()` 和统一摄取仓库。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay/RelayProtocol.kt` —— v2 载荷、ACK、错误码和版本协商模型。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay/SmsRelayForegroundService.kt` —— 原生 `START_STICKY` 前台服务、WebSocket、心跳和发送循环。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay/OutboxWorker.kt` —— WorkManager 恢复任务。
- 修改：`BootReceiver.kt`、`WatchdogReceiver.kt`、`SmsKeepAliveHelper.kt`、`BackgroundServiceStarter.kt`、`AndroidManifest.xml` —— 统一守护新服务，迁移旧 Flutter 服务入口。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NativeConfigStore.kt` —— 从 `FlutterSharedPreferences` 导入并原子保存配置。
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NativeRelayMethodChannel.kt` —— Flutter 读取健康快照、配置和诊断数据的桥接。
- 测试：`sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/storage/*Test.kt`、`ingest/SmsIngestorTest.kt`、`relay/*Test.kt`、`NativeConfigStoreTest.kt`。

### 服务端

- 修改：`sms-sync/server/package.json`、`package-lock.json` —— 增加 SQLite 驱动与迁移命令。
- 创建：`sms-sync/server/src/persistence/sqlite-store.js` —— 数据库连接、迁移、事务和备份接口。
- 创建：`sms-sync/server/src/persistence/schema.sql` —— devices/messages/deliveries/system_events 表及唯一索引。
- 创建：`sms-sync/server/src/protocol/v2.js` —— 注册、消息、ACK、replay 载荷校验。
- 修改：`sms-sync/server/src/ws-relay.js` —— v2 持久入库、ACK、重连补发和 v1 兼容。
- 修改：`sms-sync/server/src/app.js`、`index.js`、`config.js` —— 注入持久存储、维护任务和健康统计。
- 修改：`sms-sync/server/src/lib/relay-store.js` —— 保留在线 socket 索引，移除其作为消息事实来源的职责。
- 创建：`sms-sync/server/test/reliable-relay.test.js`、`protocol-v2.test.js`、`sqlite-store.test.js`、`replay.test.js`。
- 修改：`sms-sync/server/deploy.sh` —— 部署前备份数据库，部署后执行 schema/health/replay smoke check。

### 桌面端

- 创建：`sms-sync/desktop/main/services/inbox-store.js` —— 本地 Inbox、幂等写入和清理策略。
- 修改：`sms-sync/desktop/main/app.js`、`main/transport/websocket-client.js`、`preload.js` —— v2 注册、replay、落盘后 ACK。
- 修改：`sms-sync/desktop/renderer/app.js`、`renderer/styles.css`、`index.html` —— 交付状态、积压信息和移动端令牌统一。
- 测试：`sms-sync/desktop/test/services/inbox-store.test.js`、`delivery-ack.test.js`、`replay.test.js`、`renderer/delivery-health.test.js`。

### Flutter UI

- 修改：`sms-sync/mobile/lib/app/sms_sync_app.dart` —— A 方向主题令牌、字体、Material 组件默认样式。
- 创建：`sms-sync/mobile/lib/ui/theme/sms_sync_theme.dart` —— 暖灰、墨绿、状态色、间距与圆角常量。
- 创建：`sms-sync/mobile/lib/ui/guardian/guardian_page.dart`、`guardian_view_model.dart` —— 守护首页。
- 创建：`sms-sync/mobile/lib/ui/records/records_page.dart`、`delivery_timeline.dart` —— 消息记录与 ACK 时间线。
- 创建：`sms-sync/mobile/lib/ui/reliability/reliability_setup_page.dart` —— 权限和后台可靠性向导。
- 创建：`sms-sync/mobile/lib/ui/settings/settings_page.dart`、`diagnostics_page.dart` —— 连接、运行和诊断。
- 修改：`sms-sync/mobile/lib/ui/home_page.dart`、`home/home_view_state.dart`、`home/home_bottom_nav_bar.dart` —— 兼容旧入口并切换新页面。
- 创建：`sms-sync/mobile/lib/platform/native_relay_channel.dart` —— 健康快照、队列和配置 API。
- 测试：`sms-sync/mobile/test/ui/guardian/*_test.dart`、`records/*_test.dart`、`reliability/*_test.dart`、`settings/*_test.dart`、`platform/native_relay_channel_test.dart`。

### 文档与验证

- 创建：`sms-sync/mobile/docs/plans/2026-09-01-native-relay-implementation.md` —— 移动端专项实施记录。
- 修改：`sms-sync/mobile/README.md`、`README.md`、`AGENTS.md` —— 新的启动、权限、部署和验证命令。
- 创建：`sms-sync/server/test/fixtures/reliable-session.js` —— 可复用的端到端测试夹具。

---

### 任务 1：锁定 v2 协议与跨端状态机

**文件：**
- 创建：`sms-sync/server/src/protocol/v2.js`
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay/RelayProtocol.kt`
- 创建：`sms-sync/server/test/protocol-v2.test.js`
- 创建：`sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/relay/RelayProtocolTest.kt`

- [ ] **步骤 1：编写失败测试**

```js
test('normalizes an sms envelope without dropping its stable id', () => {
  const envelope = normalizeSms({
    protocolVersion: 2,
    type: 'sms',
    messageId: 'm-1',
    groupId: 'g1',
    sourceDeviceId: 'phone-1',
    from: '95588',
    body: '验证码 482913',
    receivedAt: 1700000000000,
  })
  assert.equal(envelope.messageId, 'm-1')
  assert.equal(envelope.protocolVersion, 2)
})

test('rejects an acknowledgement for a different message', () => {
  assert.equal(isMatchingAck({ messageId: 'm-1' }, { messageId: 'm-2' }), false)
})
```

```kotlin
@Test fun `backoff increases and caps at thirty minutes`() {
    assertEquals(2_000L, RetryPolicy.delayMillis(1))
    assertEquals(1_800_000L, RetryPolicy.delayMillis(99))
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`npm test -- --test-name-pattern="normalizes an sms envelope|rejects an acknowledgement"` 和 `./gradlew test --tests com.smssync.sms_sync_mobile.relay.RelayProtocolTest`

预期：FAIL，提示协议函数与 `RetryPolicy` 尚未定义。

- [ ] **步骤 3：编写最少实现**

在 Node 端导出 `normalizeRegister`、`normalizeSms`、`normalizeAck`、`isMatchingAck`；在 Kotlin 端定义 `SmsEnvelope`、`ServerAck`、`DeliveryAck`、`RetryPolicy`，所有字段显式校验，禁止用 `Map<String, Any>` 代替协议类型。

- [ ] **步骤 4：运行测试验证通过**

运行同一组命令，预期 Node 与 Kotlin 测试全部 PASS。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/server/src/protocol/v2.js sms-sync/server/test/protocol-v2.test.js sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay/RelayProtocol.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/relay/RelayProtocolTest.kt
git commit -m "feat: define reliable relay protocol v2"
```

### 任务 2：建立 Room Outbox 与原生配置迁移

**文件：**
- 修改：`sms-sync/mobile/android/settings.gradle.kts`、`app/build.gradle.kts`
- 创建：`storage/OutboxDatabase.kt`、`storage/OutboxDao.kt`、`storage/OutboxRepository.kt`、`NativeConfigStore.kt`
- 创建：`storage/OutboxRepositoryTest.kt`、`NativeConfigStoreTest.kt`

- [ ] **步骤 1：编写失败测试**

```kotlin
@Test fun `insert is idempotent for the same fingerprint`() = runTest {
    val first = repository.ingest(sampleSms(fingerprint = "fp-1"))
    val second = repository.ingest(sampleSms(fingerprint = "fp-1"))
    assertTrue(first.inserted)
    assertFalse(second.inserted)
    assertEquals(1, dao.count())
}

@Test fun `expired send lease returns item to retry wait`() = runTest {
    val item = repository.ingest(sampleSms("fp-2")).message!!
    repository.claim(item.messageId, leaseUntil = 10L)
    repository.recoverExpiredLeases(now = 11L)
    assertEquals(OutboxState.RETRY_WAIT, dao.find(item.messageId)!!.state)
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew test --tests com.smssync.sms_sync_mobile.storage.OutboxRepositoryTest --tests com.smssync.sms_sync_mobile.NativeConfigStoreTest`

预期：FAIL，因为 Room 实体、DAO 和配置迁移尚不存在。

- [ ] **步骤 3：编写最少实现**

引入 `androidx.room:room-runtime`、`room-ktx`、KAPT；创建 `outbox_messages` 与 `ingest_fingerprints` 实体。DAO 必须用事务实现“指纹检查 + 消息插入”，领取使用 `leaseUntil`，ACK 只允许 `SENDING`/`RETRY_WAIT` 转为 `SERVER_ACKED`。配置迁移使用版本键和 `SharedPreferences.edit().commit()`，成功导入 Room 后才删除旧 pending JSON。

- [ ] **步骤 4：运行测试验证通过**

运行同一 Gradle 命令，预期 PASS，并检查 `app/build/generated` 已生成 Room 实现。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/mobile/android/settings.gradle.kts sms-sync/mobile/android/app/build.gradle.kts sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/storage sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/NativeConfigStore.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/storage sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/NativeConfigStoreTest.kt
git commit -m "feat: add durable native sms outbox"
```

### 任务 3：统一短信摄取、multipart 合并与持久去重

**文件：**
- 创建：`sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/ingest/SmsIngestor.kt`
- 修改：`SmsReceiver.kt`、`SmsNotificationListenerService.kt`
- 创建：`ingest/SmsIngestorTest.kt`

- [ ] **步骤 1：编写失败测试**

```kotlin
@Test fun `multipart pdus become one outbox message`() {
    val result = ingestor.ingestSmsReceived(listOf(
        pdu("95588", "验证码 482"),
        pdu("95588", "913，请勿泄露"),
    ))
    assertEquals("验证码 482913，请勿泄露", result.single().body)
}

@Test fun `notification candidate matching a recent sms is ignored`() {
    ingestor.ingest(sampleSms("95588", "验证码 482913", 1000L, "sms_receiver"))
    val result = ingestor.ingest(sampleSms("95588", "验证码 482913", 1005L, "notification_listener"))
    assertTrue(result.isDuplicate)
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew test --tests com.smssync.sms_sync_mobile.ingest.SmsIngestorTest`

预期：FAIL，当前 receiver 按 PDU 逐条转发且去重只存在静态内存变量。

- [ ] **步骤 3：编写最少实现**

实现 `SmsIngestor`：按 subscription/reference 排序拼接 multipart；标准化发送方、换行和空白计算指纹；调用 `OutboxRepository.ingest`；在 receiver 内使用 `goAsync()`，所有异常写错误码并确保 `finish()` 在 finally 执行。通知监听器只构造候选，不直接调用 Flutter MethodChannel。

- [ ] **步骤 4：运行测试验证通过**

运行同一命令，预期 PASS；再运行 `./gradlew test --tests '*SmsReceiver*'` 确认旧 action 过滤未改变。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/ingest sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsReceiver.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsNotificationListenerService.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/ingest
git commit -m "feat: persist and deduplicate native sms ingestion"
```

### 任务 4：实现原生前台中继服务与 WorkManager 恢复

**文件：**
- 创建：`relay/SmsRelayForegroundService.kt`、`relay/OutboxWorker.kt`
- 修改：`AndroidManifest.xml`、`BootReceiver.kt`、`WatchdogReceiver.kt`、`SmsKeepAliveHelper.kt`、`BackgroundServiceStarter.kt`
- 创建：`relay/SmsRelayForegroundServiceTest.kt`、`relay/OutboxWorkerTest.kt`

- [ ] **步骤 1：编写失败测试**

```kotlin
@Test fun `server ack marks message delivered`() = runTest {
    val item = repository.ingest(sampleSms("fp-3")).message!!
    relay.handleServerAck(ServerAck(item.messageId, 2000L))
    assertEquals(OutboxState.SERVER_ACKED, dao.find(item.messageId)!!.state)
}

@Test fun `network failure schedules the next retry without deleting message`() = runTest {
    val item = repository.ingest(sampleSms("fp-4")).message!!
    relay.send(item, FakeTransport.Failure)
    assertEquals(OutboxState.RETRY_WAIT, dao.find(item.messageId)!!.state)
    assertTrue(dao.find(item.messageId)!!.attemptCount == 1)
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew test --tests com.smssync.sms_sync_mobile.relay.SmsRelayForegroundServiceTest --tests com.smssync.sms_sync_mobile.relay.OutboxWorkerTest`

预期：FAIL，因为当前只有 Flutter `BackgroundService`，没有原生消费循环。

- [ ] **步骤 3：编写最少实现**

创建通知渠道和 `SmsRelayForegroundService`，`onStartCommand` 返回 `START_STICKY`；启动 WebSocket 后先发送 v2 register，再领取带租约的 Outbox 项，收到匹配 `server-ack` 才更新数据库。连接、ACK 和发送均有 8 秒超时；失败走退避并安排唯一 `OutboxWorker`。Worker 使用 `NetworkType.CONNECTED`，恢复过期租约后消费可发送项目。Manifest 声明 `FOREGROUND_SERVICE_REMOTE_MESSAGING`、`stopWithTask=false` 和新 service；旧 `flutter_background_service` 暂时保留但不再启动业务发送。

- [ ] **步骤 4：运行测试验证通过**

运行同一 Gradle 命令，预期 PASS；运行 `./gradlew lint` 检查前台服务类型和 exported 配置。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/relay sms-sync/mobile/android/app/src/main/AndroidManifest.xml sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BootReceiver.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/WatchdogReceiver.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/SmsKeepAliveHelper.kt sms-sync/mobile/android/app/src/main/kotlin/com/smssync/sms_sync_mobile/BackgroundServiceStarter.kt sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/relay
git commit -m "feat: move sms delivery to sticky native relay"
```

### 任务 5：建立服务端 SQLite Inbox、Delivery 与 replay

**文件：**
- 修改：`sms-sync/server/package.json`、`package-lock.json`、`src/config.js`、`src/app.js`、`src/ws-relay.js`
- 创建：`src/persistence/schema.sql`、`src/persistence/sqlite-store.js`
- 创建：`test/sqlite-store.test.js`、`test/reliable-relay.test.js`、`test/replay.test.js`

- [ ] **步骤 1：编写失败测试**

```js
test('server ack is emitted only after the message transaction commits', async () => {
  const store = await createTestStore()
  const result = await store.acceptSms(envelope('m-1'))
  assert.equal(result.ack.messageId, 'm-1')
  assert.equal((await store.getMessage('g1', 'm-1')).state, 'persisted')
})

test('reconnecting desktop receives unacked delivery after server restart', async () => {
  const first = await createTestStore({ file: fixturePath('restart.sqlite') })
  await first.acceptSms(envelope('m-2'))
  await first.close()
  const second = await createTestStore({ file: fixturePath('restart.sqlite') })
  assert.equal((await second.pendingDeliveries('desktop-1'))[0].messageId, 'm-2')
})
```

- [ ] **步骤 2：运行测试验证失败**

运行：`npm test -- --test-name-pattern="server ack is emitted|reconnecting desktop"`

预期：FAIL，因为当前 relay-store 只存在内存数组和在线 socket。

- [ ] **步骤 3：编写最少实现**

新增 SQLite 驱动和迁移。表结构包含 `devices`、`messages`、`deliveries`、`system_events`，对 `(group_id,message_id)` 建唯一索引。`acceptSms` 在事务中幂等写入消息并建立目标 delivery，事务提交后生成 server ACK。`pendingDeliveries` 按设备读取未 ACK 项；socket close 不删除数据库记录。保留 v1 即时转发分支并在日志中标记 `legacy`。

- [ ] **步骤 4：运行测试验证通过**

运行同一 npm 命令及 `npm test`，预期 PASS；验证服务重启后 schema 不重复创建。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/server/package.json sms-sync/server/package-lock.json sms-sync/server/src/config.js sms-sync/server/src/app.js sms-sync/server/src/ws-relay.js sms-sync/server/src/persistence sms-sync/server/test/sqlite-store.test.js sms-sync/server/test/reliable-relay.test.js sms-sync/server/test/replay.test.js
git commit -m "feat: persist relay inbox and desktop deliveries"
```

### 任务 6：实现桌面端持久 Inbox、ACK 与断线补拉

**文件：**
- 创建：`sms-sync/desktop/main/services/inbox-store.js`
- 修改：`sms-sync/desktop/main/app.js`、`main/transport/websocket-client.js`、`preload.js`
- 创建：`sms-sync/desktop/test/services/inbox-store.test.js`、`delivery-ack.test.js`、`replay.test.js`

- [ ] **步骤 1：编写失败测试**

```js
test('desktop acknowledges only after durable insert', async () => {
  const store = createInboxStore(tempDb())
  const sent = []
  await handleDelivery(envelope('m-3'), { store, sendAck: (ack) => sent.push(ack) })
  assert.equal((await store.get('m-3')).messageId, 'm-3')
  assert.equal(sent[0].messageId, 'm-3')
})

test('duplicate delivery does not trigger a second notification', async () => {
  const notifications = []
  const store = createInboxStore(tempDb())
  await handleDelivery(envelope('m-4'), { store, notify: (msg) => notifications.push(msg) })
  await handleDelivery(envelope('m-4'), { store, notify: (msg) => notifications.push(msg) })
  assert.equal(notifications.length, 1)
})
```

- [ ] **步骤 2：运行测试验证失败**

运行：`npm test -- --test-name-pattern="durable insert|second notification"`（工作目录 `sms-sync/desktop`）。

预期：FAIL，因为消息当前直接进入 renderer 内存数组。

- [ ] **步骤 3：编写最少实现**

使用 Electron `app.getPath('userData')` 下的 SQLite 文件保存 Inbox、唯一 `messageId`、接收时间和签名校验结果。主进程处理 v2 delivery：校验、事务插入、ACK、首次插入才通知。重连注册载荷声明 `replay`，服务端补发仍走同一处理函数。preload 只暴露事件订阅和只读查询，不暴露数据库句柄。

- [ ] **步骤 4：运行测试验证通过**

运行 `npm test` 和 `npm run lint`，预期 PASS；手动重启 Electron 后确认历史 Inbox 恢复。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/desktop/main/services/inbox-store.js sms-sync/desktop/main/app.js sms-sync/desktop/main/transport/websocket-client.js sms-sync/desktop/preload.js sms-sync/desktop/test/services/inbox-store.test.js sms-sync/desktop/test/services/delivery-ack.test.js sms-sync/desktop/test/services/replay.test.js
git commit -m "feat: persist desktop inbox before ack"
```

### 任务 7：接入原生状态桥并重做移动端 A 方向 UI

**文件：**
- 修改：`sms-sync/mobile/lib/app/sms_sync_app.dart`、`lib/ui/home_page.dart`、`lib/ui/home/home_view_state.dart`
- 创建：`lib/ui/theme/sms_sync_theme.dart`、`lib/platform/native_relay_channel.dart`
- 创建：`lib/ui/guardian/guardian_page.dart`、`guardian_view_model.dart`
- 创建：`lib/ui/records/records_page.dart`、`delivery_timeline.dart`
- 创建：`lib/ui/reliability/reliability_setup_page.dart`
- 创建：`lib/ui/settings/settings_page.dart`、`diagnostics_page.dart`
- 创建：`test/ui/guardian/guardian_page_test.dart`、`test/ui/records/records_page_test.dart`、`test/ui/reliability/reliability_setup_page_test.dart`、`test/ui/settings/settings_page_test.dart`

- [ ] **步骤 1：编写失败测试**

```dart
testWidgets('guardian page shows queue problem with a recovery action', (tester) async {
  await tester.pumpWidget(testApp(const NativeHealthSnapshot(
    state: HealthState.degraded,
    reason: 'server_unreachable',
    pendingCount: 2,
  )));
  expect(find.text('正在重试'), findsOneWidget);
  expect(find.text('查看记录'), findsOneWidget);
});

testWidgets('records page shows ack timeline without color-only status', (tester) async {
  await tester.pumpWidget(testApp(sampleRecordsPage()));
  expect(find.text('手机已接收'), findsOneWidget);
  expect(find.text('服务端已保存'), findsOneWidget);
  expect(find.text('桌面端已确认'), findsOneWidget);
});
```

- [ ] **步骤 2：运行测试验证失败**

运行：`flutter test test/ui/guardian/guardian_page_test.dart test/ui/records/records_page_test.dart`。

预期：FAIL，因为新页面和原生健康快照尚不存在。

- [ ] **步骤 3：编写最少实现**

创建主题令牌：`#F4F1EB` 背景、`#18382F` 主状态、`#20221F` 正文、低饱和警告色；禁用渐变和玻璃拟态。底部导航固定为同步、记录、设置。同步页只显示健康状态、已送达、待重试和最近活动；记录页显示状态标签和 ACK 时间线；可靠性向导逐项引导权限；设置页收纳连接、运行和应用。所有状态同时使用文字和图标，交互控件添加 `Semantics`。通过 MethodChannel 获取健康快照、队列计数、最近 ACK 和诊断事件，不再监听 Flutter 后台 isolate 的“在线”事件。

- [ ] **步骤 4：运行测试验证通过**

运行：`flutter test test/ui test/platform` 和 `flutter analyze`，预期 PASS、无新增 lint。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/mobile/lib/app/sms_sync_app.dart sms-sync/mobile/lib/ui sms-sync/mobile/lib/platform/native_relay_channel.dart sms-sync/mobile/test/ui sms-sync/mobile/test/platform
git commit -m "feat: redesign mobile guardian and delivery UI"
```

### 任务 8：移除 Flutter 交付单点并完成兼容迁移

**文件：**
- 修改：`sms-sync/mobile/lib/background/background_runtime.dart`、`lib/services/message_transport_service.dart`、`lib/app/service_registry.dart`、`android/app/src/main/AndroidManifest.xml`
- 创建：`sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/MigrationCompatibilityTest.kt`
- 修改：`sms-sync/mobile/test/services/settings_repository_test.dart`

- [ ] **步骤 1：编写失败测试**

```kotlin
@Test fun `legacy flutter pending queue is imported before deletion`() {
    val prefs = legacyPrefsWithPendingSms("legacy-1")
    val migration = NativeConfigStore(prefs, database)
    migration.importLegacyState()
    assertEquals("legacy-1", database.outbox().first().body)
    assertNull(prefs.getString("flutter.pendingNativeSmsQueue", null))
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`./gradlew test --tests com.smssync.sms_sync_mobile.MigrationCompatibilityTest` 和 `flutter test test/services/settings_repository_test.dart`。

预期：FAIL，旧路径仍由 Flutter `background_runtime.dart` 发送且没有原生迁移入口。

- [ ] **步骤 3：编写最少实现**

保留 Flutter 端配置与 UI 兼容 API，但删除 `background_runtime.dart` 中的短信发送循环、临时 WebSocket 和 pending queue 消费；改为调用 `NativeRelayMethodChannel`。旧 JSON 队列导入 Room 后再清理。`BackgroundServiceStarter` 只作为升级期间的兼容唤醒器，不再创建业务 socket。Manifest 同时保留旧 service 声明一个版本周期，禁止两个发送器并行运行。

- [ ] **步骤 4：运行测试验证通过**

运行：`./gradlew test`、`flutter test`、`flutter analyze`，预期全部通过。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/mobile/lib/background/background_runtime.dart sms-sync/mobile/lib/services/message_transport_service.dart sms-sync/mobile/lib/app/service_registry.dart sms-sync/mobile/android/app/src/main/AndroidManifest.xml sms-sync/mobile/android/app/src/test/kotlin/com/smssync/sms_sync_mobile/MigrationCompatibilityTest.kt sms-sync/mobile/test/services/settings_repository_test.dart
git commit -m "refactor: remove flutter delivery single point"
```

### 任务 9：更新桌面与服务端可观测 UI、部署和文档

**文件：**
- 修改：`sms-sync/desktop/renderer/index.html`、`renderer/app.js`、`renderer/styles.css`
- 修改：`sms-sync/server/src/app.js`、`src/config.js`、`server/deploy.sh`
- 修改：`sms-sync/mobile/README.md`、`README.md`、`AGENTS.md`
- 创建：`sms-sync/server/test/health-overview.test.js`

- [ ] **步骤 1：编写失败测试**

```js
test('health overview exposes pending and oldest delivery age', async () => {
  const overview = await api.get('/api/health/overview')
  assert.equal(typeof overview.pendingDeliveries, 'number')
  assert.ok('oldestPendingAt' in overview)
})
```

- [ ] **步骤 2：运行测试验证失败**

运行：`npm test -- --test-name-pattern="pending and oldest delivery age"`。

预期：FAIL，因为服务端和桌面端没有可靠交付指标。

- [ ] **步骤 3：编写最少实现**

管理 API 从 SQLite 聚合 `pendingDeliveries`、`retryingDeliveries`、`ackedDeliveries`、`oldestPendingAt`。桌面页面增加交付健康与积压计数，使用暖灰/墨绿令牌；服务端部署脚本增加数据库备份、迁移、健康检查和 replay smoke check。文档明确新的 `npm test`、Gradle、Flutter 命令和 Android 可靠性设置向导。

- [ ] **步骤 4：运行测试验证通过**

运行服务端、桌面端测试和 lint，预期 PASS；执行 `bash sms-sync/server/deploy.sh --dry-run`（若脚本不支持 dry-run，则运行其中的备份/迁移命令在本地临时目录验证）。

- [ ] **步骤 5：Commit**

```bash
git add sms-sync/desktop/renderer sms-sync/server/src sms-sync/server/deploy.sh sms-sync/server/test/health-overview.test.js sms-sync/mobile/README.md README.md AGENTS.md
git commit -m "feat: expose reliable delivery health"
```

### 任务 10：端到端压力验证与服务端实际部署

**文件：**
- 创建：`sms-sync/server/test/fixtures/reliable-session.js`
- 创建：`sms-sync/mobile/docs/plans/2026-09-01-native-relay-implementation.md`
- 修改：不预设；仅修复验证中被失败测试捕获的缺陷。

- [ ] **步骤 1：编写失败的端到端场景**

在 Node fixture 中建立手机、服务端、桌面三个 WebSocket 客户端，发送 100 条带唯一 ID 的短信；在每个 ACK 边界随机断开连接，断开服务端进程后重新启动，断开桌面 60 秒后重新连接。断言最终 100 条均有 `desktop_acked`，桌面通知回调只触发 100 次。

- [ ] **步骤 2：运行测试验证失败**

运行：`npm test -- --test-name-pattern="reliable session"`。

预期：在可靠协议尚未完全接通前失败，并指出未确认的 `messageId`。

- [ ] **步骤 3：修复最小根因**

只修复失败断点对应的一层：手机 Outbox、服务端事务/replay 或桌面 Inbox/ACK；禁止用增加等待时间、放宽断言或删除测试来掩盖失败。每个修复都先补充针对性单元测试。

- [ ] **步骤 4：运行完整验证**

按顺序运行：

```powershell
cd sms-sync/server; npm test
cd ../desktop; npm test; npm run lint
cd ../mobile; flutter test; flutter analyze
cd android; .\gradlew test; .\gradlew lint
```

在 Android 16 实机执行锁屏、断网、服务端重启、桌面离线、应用升级、watchdog 恢复和通知监听重绑；使用 `messageId` 对账，预期所有消息进入 `desktop_acked`，桌面通知无重复。

- [ ] **步骤 5：按现有流程部署服务端并验证**

先备份远端 SQLite，再按 `sms-sync/server/deploy.sh` 的 PM2/SSH 流程部署兼容 v1/v2 的服务端。部署后验证旧客户端连接、v2 server ACK、桌面离线补发、进程重启恢复和管理页积压指标。记录远端 PM2 日志、数据库迁移版本和 smoke test 结果。

- [ ] **步骤 6：Commit**

```bash
git add sms-sync/server/test/fixtures/reliable-session.js sms-sync/mobile/docs/plans/2026-09-01-native-relay-implementation.md
git commit -m "test: verify end to end reliable delivery"
```

---

## 计划自检

- 规格中的 UI、原生保活、持久 Outbox、服务端持久 Inbox、桌面 ACK、迁移、可观测性、部署和端到端验收均有对应任务。
- 已扫描计划中的未完成标记、模糊步骤和未决方案；不存在未定义的功能名或未决方案。
- 协议字段在任务 1 定义，Room 状态在任务 2 定义，任务 4/5/6/7 均复用相同的 `messageId`、`server-ack`、`delivery-ack` 和状态名。
- 旧协议兼容、Flutter pending JSON 迁移和现有配置保留在任务 5、8、9 中明确实现，不依赖隐含步骤。
- 服务端改动包含实际部署与备份验证；移动端不新增厂商专用 API；桌面端只修改可靠协议必需部分和视觉令牌。

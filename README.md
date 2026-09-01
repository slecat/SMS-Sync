# SMS Sync

一个用于短信同步的多端项目，支持 Android 手机接收短信并同步到桌面端，同时支持局域网直连和服务器中转。

## 项目结构

- `sms-sync/mobile`：Flutter Android 客户端，负责短信接收与转发
- `sms-sync/desktop`：Electron 桌面端，负责短信展示与通知
- `sms-sync/server`：Node.js WebSocket 中转服务

## 核心能力

- 局域网 UDP 广播同步，同网段可自动发现设备
- WebSocket 服务器中转，支持跨网络同步
- 同步密钥签名校验，使用 HMAC-SHA256
- 移动端后台服务与前台通知常驻
- 移动端短信先写入原生 Room Outbox，再由原生前台中继通过 ACK WebSocket 发送；Flutter isolate 不再参与短信交付，服务端事件和桌面端 Inbox 均支持落盘恢复
- WebSocket v2 提供 server-ack / delivery-ack，断线后按 2 秒至 30 分钟退避重试

## 同步密钥说明

- `同步密钥` 为必填项，且所有参与同步的设备必须保持一致。
- 移动端和桌面端都会对关键消息，如 `sms`、`test`、`device-presence` 做签名或验签。
- 密钥不一致时，消息会被判定为不可信并丢弃。

## 快速开始

### 1) 启动服务端

```bash
cd sms-sync/server
npm install
node index.js
```

默认端口为 `8004`，可通过环境变量 `PORT` 覆盖。

服务端事件默认持久化到 `sms-sync/server/data/relay-events.json`，可通过 `RELAY_PERSISTENCE_PATH` 指定路径。生产环境请将该目录纳入备份。

如果是线上服务器部署，服务端代码修改后需要同步到服务器，并按项目现有的 SSH 运维流程执行部署。可优先参考：

```bash
sms-sync/server/deploy.sh
```

### 2) 启动桌面端

```bash
cd sms-sync/desktop
npm install
npm start
```

在设置中填写：

- 组 ID
- 同步密钥
- 服务器地址，可选
- 设备名称

### 3) 启动移动端

```bash
cd sms-sync/mobile
flutter pub get
flutter run
```

在设置中填写：

- 组 ID
- 同步密钥
- 服务器地址，可选
- 设备名称

## 打包

移动端和桌面端打包统一使用：

```bat
cd sms-sync
package_all.bat
```

该脚本会完成移动端 APK 构建和桌面端安装包构建，并将产物输出到 `sms-sync/output/`。

## 开发与测试

### Mobile

```bash
cd sms-sync/mobile
flutter analyze
flutter test
```

### Desktop

```bash
cd sms-sync/desktop
npm run lint
npm test
```

### Server

```bash
cd sms-sync/server
npm install
node index.js
```

## 注意事项

- Android 端需要授予短信、通知和后台运行相关权限。
- 部分 ROM 会限制后台常驻，建议关闭电池优化。
- 原生中继服务使用 `START_STICKY`、WorkManager 租约恢复和启动广播；用户在系统设置中“强行停止”应用后，Android 不允许应用自行重启，这是系统级限制。
- `sms-sync/mobile` 使用 `dependency_overrides` 指向本地 `third_party/flutter_background_service_android`，修改时需要注意这是仓库内维护的定制依赖。
- 服务端相关改动如果只停留在本地仓库，线上环境不会自动生效，部署时要同步走项目内已有的 SSH 流程。

## Android 验证码兼容说明

- 某些 ROM 或短信应用不会把验证码短信暴露给第三方应用的短信数据库读取接口。
- 遇到“短信应用里能看到，但 `sms-sync` 读不到”的情况时，请先在手机端设置页面手动开启通知监听。
- 当前版本会优先使用标准短信接收链路；系统隐藏短信时，会从短信应用通知中提取验证码正文作为兜底。
- 通知监听兜底仅处理常见短信应用通知，并且只接受明显包含“验证码 + 数字”的内容。

# SMS Sync

一个用于短信同步的多端项目，支持 Android 手机接收短信并同步到桌面端，支持局域网直连和服务器中转。

## 项目结构

- `sms-sync/mobile`：Flutter Android 客户端（短信接收与转发）
- `sms-sync/desktop`：Electron 桌面端（短信展示与通知）
- `sms-sync/server`：Node.js WebSocket 中转服务

## 核心能力

- 局域网 UDP 广播同步（同网段可直接发现设备）
- WebSocket 服务器中转（跨网络）
- 同步密钥签名校验（HMAC-SHA256）
- 手机端后台服务与前台通知常驻

## 同步密钥说明（重要）

- `同步密钥` 为必填项，且所有参与同步的设备必须保持一致。
- 手机端和桌面端均会对关键消息（`sms` / `test` / `device-presence`）做签名或验签。
- 密钥不一致时，消息会被判定为不可信并丢弃。

## 快速开始

### 1) 启动服务端

```bash
cd sms-sync/server
npm install
node index.js
```

默认端口 `8004`（可通过环境变量 `PORT` 覆盖）。

### 2) 启动桌面端

```bash
cd sms-sync/desktop
npm install
npm start
```

在设置中填写：
- 组 ID
- 同步密钥（必填）
- 服务器地址（可选，跨网络建议配置）
- 设备名称

### 3) 启动移动端

```bash
cd sms-sync/mobile
flutter pub get
flutter run
```

在设置中填写：
- 组 ID
- 同步密钥（必填）
- 服务器地址（可选）
- 设备名称

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

## 注意事项

- Android 端需授予短信、通知、后台运行相关权限。
- 部分 ROM 会限制后台常驻，建议关闭电池优化。
- `sms-sync/mobile` 使用了 `dependency_overrides` 指向本地：
  - `third_party/flutter_background_service_android`
  请确保该目录随仓库一起维护。

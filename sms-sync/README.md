# 短信同步系统

将 Android 手机的短信（特别是验证码）同步到 Windows 电脑上，支持局域网直连和服务器中转两种方式。

## 组件说明

1. **server**：Node.js WebSocket 服务器，用于在设备不在同一网络时中转消息
2. **mobile**：Flutter Android 应用，用于发送短信
3. **desktop**：Electron Windows 应用，用于接收和显示短信

## 安装和使用说明

### 服务器端（Ubuntu）

1. 安装 Node.js（v18 或更高版本）
2. 将 `server` 目录复制到 Ubuntu 服务器
3. 运行 `npm install` 安装依赖
4. 将 `.env.example` 复制为 `.env` 并设置端口号
5. 运行 `node index.js` 启动服务器

### 手机端（Android）

1. 安装 Flutter
2. 打开 `mobile` 目录
3. 运行 `flutter pub get` 安装依赖
4. 连接 Android 设备
5. 运行 `flutter run` 安装应用
6. 打开应用，记下"您的设备 ID"
7. 在"目标设备 ID"中输入电脑端的设备 ID
8. （可选）如果使用远程同步，输入服务器地址

### 电脑端（Windows）

1. 安装 Node.js（v18 或更高版本）
2. 打开 `desktop` 目录
3. 运行 `npm install` 安装依赖
4. 运行 `npm start` 启动应用
5. 打开应用，记下"设备 ID"
6. （可选）如果使用远程同步，输入服务器地址
7. 应用将在 Windows 开机时自动启动

## 使用方式

### 同一局域网内
- 两个设备会自动发现对方并通过 UDP 广播同步消息

### 不同网络
- 确保两个设备都配置了服务器地址
- 服务器会在设备之间中转消息

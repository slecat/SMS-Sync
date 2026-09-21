# Sms-Sync 代理指南

## 适用范围

- 本文件作用于仓库根目录。
- 实际业务代码位于仓库根目录下的 `mobile/`、`desktop/`、`server/`。
- `README.md` 面向人阅读，本文件面向代理或自动化协作者执行任务。

## 仓库结构

- `mobile`：Flutter Android 客户端，负责短信采集、后台运行和移动端同步配置。
- `desktop`：Electron 桌面端，负责设备配对、消息展示和桌面通知。
- `server`：Node.js WebSocket 中转服务，用于跨网络同步。
- `package_all.bat`：移动端 APK 和桌面端安装包的一键打包入口。
- `docs/`：仓库级设计文档与实施计划，历史计划文档按日期归档。
- `remote-snapshots/`：运维或快照参考目录，除非任务明确要求，否则不要修改。
- `.codex/`、`.opencode/`、`.superpowers/`、`.tools/`：本地工具和代理辅助目录，除非任务明确要求，否则不要修改。

## 工作位置

- 做产品相关修改时，直接在根目录对应的 `mobile`、`desktop`、`server` 子项目内进行。
- 优先只改当前任务对应的子项目，避免同时改动 `mobile`、`desktop`、`server`。
- 开始编辑前先执行 `git status --short`，确认工作区里是否已经存在用户改动。

## 常用命令

### Server

在 `server` 下执行：

```powershell
npm install
node index.js
```

### Desktop

在 `desktop` 下执行：

```powershell
npm install
npm start
npm run lint
npm test
```

### Mobile

在 `mobile` 下执行：

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

### Packaging

在仓库根目录下执行：

```powershell
.\package_all.bat
```

- 移动端和桌面端打包统一走 `package_all.bat`。
- 除非任务明确要求拆分打包流程，否则不要分别手工改写移动端和桌面端打包步骤。

## 修改约束

- 除非任务明确与构建产物有关，否则不要修改生成目录或打包输出。
- 通常不要编辑 `desktop/dist`、`output`、`mobile/build` 以及任何 `node_modules` 目录。
- `mobile/third_party/flutter_background_service_android` 是仓库内维护的第三方定制依赖，只有任务明确涉及它时才修改。
- 服务器端代码有变更时，不要只停留在本地仓库；需要按照项目内现有 SSH/运维流程同步到服务器。
- 服务端部署相关操作优先参考 `server/deploy.sh` 和项目内已有 SSH 约定，避免发明新的手工部署流程。
- 未经要求，不要新增根目录脚本、工具链配置或新的包管理入口。
- 变更应尽量聚焦当前任务，避免顺手做跨端重构或无关清理。

## 文档规则

- 如果你改了启动命令、测试命令、打包方式或仓库结构，必须同步更新 `README.md` 和 `AGENTS.md`。
- 仓库级约定写在这里，子项目细节优先写到对应子项目的 README 或本地文档。
- 新增仓库级设计文档或实施计划时，放到 `docs/plans/`。

## 完成前检查

- 在声明完成前，核对命令和路径是否与当前仓库实际一致。
- 说明本次修改触达了哪个子项目，并说明执行过哪些验证命令。
- 如果涉及 `server` 目录改动，说明是否已同步处理部署步骤，或明确说明这一步尚未执行。
- 如果工作区本来就是脏的，不要回退与当前任务无关的用户改动。

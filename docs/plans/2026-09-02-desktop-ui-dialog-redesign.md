# 桌面端双栏与稳定弹窗实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现 B 方案双栏桌面工作区、移动端统一视觉和可复用的稳定弹窗。

**架构：** 渲染层用 CSS 令牌和左侧导航/右侧工作区重排现有页面；主进程将应用内弹窗封装为单实例状态机，失败时回退系统通知。消息数据流和 WebSocket 协议保持不变。

**技术栈：** Electron、原生 HTML/CSS/JavaScript、Node `node:test`、ESLint、electron-builder。

---

### 任务 1：弹窗稳定性回归测试

**文件：**
- 修改：`sms-sync/desktop/main/services/in-app-alert-service.js`
- 创建：`sms-sync/desktop/test/in-app-alert-service.test.js`

- [x] 编写失败测试：连续 `showAlert` 只保留一个窗口、旧 timer 不关闭新窗口、窗口加载失败触发回退、复制回调异常后服务仍可关闭。
- [x] 运行 `npm test -- test/in-app-alert-service.test.js`，确认因当前实现缺少注入和 token 校验而失败。
- [x] 实现最小单实例状态机、窗口 token、统一计时器清理和系统通知回退注入。
- [x] 重跑该测试并确认通过。
- [x] 提交 `test: cover desktop alert lifecycle`。

### 任务 2：弹窗视觉与交互

**文件：**
- 修改：`sms-sync/desktop/main/services/in-app-alert-service.js`
- 修改：`sms-sync/desktop/main/ipc.js`（如需新增复制 IPC）
- 修改：`sms-sync/desktop/main/app.js`（如需接入系统通知回退）

- [x] 编写失败测试：生成的 data URL 包含暖灰/白卡片、墨绿强调色、验证码等宽块、Esc 关闭和复制按钮。
- [x] 运行针对性测试确认失败。
- [x] 实现新的弹窗 HTML、CSP、复制 IPC、Esc/关闭按钮和无焦点显示。
- [x] 重跑测试确认通过。
- [x] 与生命周期实现一并提交（`test: cover desktop alert lifecycle`）。

### 任务 3：双栏桌面工作区

**文件：**
- 修改：`sms-sync/desktop/renderer/app.js`
- 修改：`sms-sync/desktop/renderer/styles.css`
- 修改：`sms-sync/desktop/test/renderer-layout.test.js`（若已有则扩展）

- [x] 编写失败测试：页面包含四项侧栏导航、消息工作区、连接状态和移动端令牌；消息列表为内部滚动。
- [x] 运行测试确认失败。
- [x] 实现左栏导航、右侧消息工作区、暖灰/墨绿令牌、响应式断点和焦点样式。
- [x] 重跑渲染测试确认通过。
- [x] 提交 `feat: align desktop workspace with mobile ui`。

### 任务 4：完整验证与打包

**文件：**
- 修改：必要时更新 `README.md` 或桌面端文档。

- [x] 运行 `npm test`、`npm run lint`。
- [x] 运行 `npm run dist:win` 生成 Windows 安装包并检查产物存在。
- [ ] 启动打包应用，验证弹窗连续消息、复制、托盘恢复和窗口关闭。
- [ ] 提交 `chore: verify desktop ui release`。

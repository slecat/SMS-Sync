const { extractVerificationCode } = require('./message-utils');

class NotificationService {
  constructor({ Notification, clipboard, getMainWindow }) {
    this.Notification = Notification;
    this.clipboard = clipboard;
    this.getMainWindow = getMainWindow;
  }

  notifyManualTest() {
    if (!this.Notification.isSupported()) {
      return;
    }

    const notification = new this.Notification({
      title: '测试通知',
      body: '这是一条测试通知消息！收到短信时会显示类似的通知。',
      silent: false,
      urgency: 'critical',
    });
    notification.show();
  }

  notifyCode(code) {
    if (!this.Notification.isSupported()) {
      return;
    }

    const notification = new this.Notification({
      title: `验证码: ${code}`,
      body: `点击复制验证码\n\n【某某应用】您的验证码是 ${code}，5分钟内有效。`,
      silent: false,
      urgency: 'critical',
    });

    notification.on('click', () => {
      this.copyCodeToClipboard(code);
    });

    notification.show();
  }

  notifySms(sms) {
    if (!this.Notification.isSupported()) {
      return;
    }

    const code = extractVerificationCode(sms.body || '');
    const notification = new this.Notification({
      title: code ? `验证码: ${code}` : `来自 ${sms.from}`,
      body: code ? `点击复制验证码\n\n${sms.body}` : sms.body,
      silent: false,
      urgency: 'critical',
    });

    if (code) {
      notification.on('click', () => {
        this.copyCodeToClipboard(code);
      });
    }

    notification.show();
  }

  notifyTest(test) {
    if (!this.Notification.isSupported()) {
      return;
    }

    const notification = new this.Notification({
      title: '测试消息',
      body: `来自 ${test.from} 的测试消息`,
      silent: false,
      urgency: 'critical',
    });
    notification.show();
  }

  copyCodeToClipboard(code) {
    this.clipboard.writeText(code);
    const window = this.getMainWindow();
    if (window) {
      window.webContents.send('code-copied', code);
    }
  }
}

module.exports = {
  NotificationService,
};

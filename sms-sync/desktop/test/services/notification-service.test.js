const test = require('node:test');
const assert = require('node:assert/strict');
const { NotificationService } = require('../../main/services/notification-service');

class FakeNotification {
  static supported = true;
  static instances = [];

  static isSupported() {
    return FakeNotification.supported;
  }

  constructor(options) {
    this.options = options;
    this.handlers = {};
    this.shown = false;
    FakeNotification.instances.push(this);
  }

  on(event, handler) {
    this.handlers[event] = handler;
  }

  show() {
    this.shown = true;
  }

  trigger(event) {
    if (this.handlers[event]) {
      this.handlers[event]();
    }
  }
}

function createService() {
  const clipboard = {
    copied: [],
    writeText(value) {
      this.copied.push(value);
    },
  };
  const sentCodes = [];
  const service = new NotificationService({
    Notification: FakeNotification,
    clipboard,
    getMainWindow: () => ({
      webContents: {
        send: (channel, code) => sentCodes.push({ channel, code }),
      },
    }),
  });

  return { service, clipboard, sentCodes };
}

test('NotificationService should skip notification when unsupported', () => {
  FakeNotification.instances = [];
  FakeNotification.supported = false;

  const { service } = createService();
  service.notifyManualTest();

  assert.equal(FakeNotification.instances.length, 0);
});

test('NotificationService should notify SMS and copy code on click', () => {
  FakeNotification.instances = [];
  FakeNotification.supported = true;

  const { service, clipboard, sentCodes } = createService();
  service.notifySms({ from: '银行', body: '您的验证码是 123456，请勿泄露。' });

  assert.equal(FakeNotification.instances.length, 1);
  const notification = FakeNotification.instances[0];
  assert.equal(notification.options.title, '验证码: 123456');
  assert.equal(notification.shown, true);

  notification.trigger('click');
  assert.deepEqual(clipboard.copied, ['123456']);
  assert.deepEqual(sentCodes, [{ channel: 'code-copied', code: '123456' }]);
});

test('NotificationService should notify SMS without click handler when no code', () => {
  FakeNotification.instances = [];
  FakeNotification.supported = true;

  const { service, clipboard } = createService();
  service.notifySms({ from: '通知', body: '今晚有系统维护公告。' });

  assert.equal(FakeNotification.instances.length, 1);
  const notification = FakeNotification.instances[0];
  assert.equal(notification.options.title, '来自 通知');
  assert.equal(typeof notification.handlers.click, 'undefined');
  assert.deepEqual(clipboard.copied, []);
});

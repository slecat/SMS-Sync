const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { InAppAlertService } = require('../main/services/in-app-alert-service');

class FakeWindow extends EventEmitter {
  static instances = [];

  constructor(options) {
    super();
    this.options = options;
    this.webContents = new EventEmitter();
    this.webContents.setWindowOpenHandler = () => {};
    this.urls = [];
    this.closed = false;
    FakeWindow.instances.push(this);
  }

  setMenuBarVisibility() {}

  setAlwaysOnTop() {}

  loadURL(url) {
    this.urls.push(url);
  }

  isDestroyed() {
    return this.closed;
  }

  showInactive() {
    this.shownInactive = true;
  }

  show() {
    this.shown = true;
  }

  close() {
    if (this.closed) return;
    this.closed = true;
    this.emit('closed');
  }
}

function createService({ onSystemNotification, onCopyCode } = {}) {
  FakeWindow.instances = [];
  return new InAppAlertService({
    BrowserWindow: FakeWindow,
    screen: {
      getPrimaryDisplay: () => ({
        workArea: { x: 0, y: 0, width: 1280, height: 800 },
      }),
    },
    onSystemNotification,
    onCopyCode,
  });
}

test('consecutive alerts reuse one window and stale timers cannot close the latest alert', () => {
  const originalSetTimeout = global.setTimeout;
  const originalClearTimeout = global.clearTimeout;
  const timers = [];
  global.setTimeout = (callback) => {
    timers.push(callback);
    return timers.length;
  };
  global.clearTimeout = () => {};

  try {
    const service = createService();
    service.showAlert({ title: '第一条', body: '内容', durationMs: 1000 });
    const firstWindow = service.alertWindow;
    service.showAlert({ title: '第二条', body: '更新后的内容', durationMs: 1000 });

    assert.equal(FakeWindow.instances.length, 1);
    assert.equal(service.alertWindow, firstWindow);
    assert.match(decodeURIComponent(firstWindow.urls.at(-1)), /更新后的内容/);

    timers[0]();
    assert.equal(service.alertWindow, firstWindow);
    assert.equal(firstWindow.closed, false);
  } finally {
    global.setTimeout = originalSetTimeout;
    global.clearTimeout = originalClearTimeout;
  }
});

test('load failure falls back to system notification and clears the alert', () => {
  const fallbackCalls = [];
  const service = createService({
    onSystemNotification: (payload) => fallbackCalls.push(payload),
  });
  service.showAlert({ title: '离线', body: '弹窗加载失败', durationMs: 1000 });
  const alertWindow = service.alertWindow;
  alertWindow.webContents.emit('did-fail-load', {}, -2, '网络错误', 'data:text/html');

  assert.equal(service.alertWindow, null);
  assert.equal(fallbackCalls.length, 1);
  assert.equal(fallbackCalls[0].title, '离线');
  assert.equal(fallbackCalls[0].body, '弹窗加载失败');
});

test('copy callback errors do not prevent closing the alert', () => {
  const service = createService({
    onCopyCode: () => {
      throw new Error('clipboard unavailable');
    },
  });
  service.showAlert({ title: '验证码', body: '123456', copyCode: '123456' });
  const alertWindow = service.alertWindow;
  alertWindow.webContents.emit('will-navigate', { preventDefault() {} }, 'sms-sync-copy://123456');

  assert.equal(service.alertWindow, null);
  assert.equal(alertWindow.closed, true);
});

test('alert data URL uses the calm desktop palette and accessible controls', () => {
  const service = createService();
  const html = decodeURIComponent(
    service.buildDataUrl('验证码', '验证码内容', '123456').split(',')[1]
  );

  assert.match(html, /#F4F1EB/i);
  assert.match(html, /#173C36/i);
  assert.match(html, /123456/);
  assert.match(html, /复制验证码/);
  assert.match(html, /Escape/);
  assert.match(html, /Content-Security-Policy/);
  assert.doesNotMatch(html, /应用内通知，自动关闭/);
});

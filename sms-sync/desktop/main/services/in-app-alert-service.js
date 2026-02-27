function escapeHtml(text = '') {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

class InAppAlertService {
  constructor({ BrowserWindow, screen, onCopyCode }) {
    this.BrowserWindow = BrowserWindow;
    this.screen = screen;
    this.onCopyCode = onCopyCode || (() => {});
    this.alertWindow = null;
    this.closeTimer = null;
  }

  showAlert({ title, body, durationMs = 12000, copyCode = null }) {
    this.closeAlert();

    const { width: popupWidth, height: popupHeight } = this.computePopupSize({
      title,
      body,
      copyCode,
    });
    const { x, y } = this.getWindowPosition(popupWidth, popupHeight);
    this.alertWindow = new this.BrowserWindow({
      width: popupWidth,
      height: popupHeight,
      x,
      y,
      frame: false,
      resizable: false,
      minimizable: false,
      maximizable: false,
      movable: false,
      skipTaskbar: true,
      alwaysOnTop: true,
      show: false,
      backgroundColor: '#111827',
      webPreferences: {
        sandbox: true,
      },
    });

    this.alertWindow.setMenuBarVisibility(false);
    this.alertWindow.setAlwaysOnTop(true, 'screen-saver');
    this.alertWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    this.alertWindow.webContents.on('will-navigate', (event, url) => {
      const code = this.parseCopyCode(url);
      if (!code) {
        return;
      }

      event.preventDefault();
      try {
        this.onCopyCode(code);
      } catch (error) {
        // Keep alert path resilient even if clipboard action fails.
        console.error('In-app alert copy failed:', error);
      }
      this.closeAlert();
    });

    this.alertWindow.loadURL(this.buildDataUrl(title, body, copyCode));
    this.alertWindow.once('ready-to-show', () => {
      if (!this.alertWindow || this.alertWindow.isDestroyed()) {
        return;
      }
      if (typeof this.alertWindow.showInactive === 'function') {
        this.alertWindow.showInactive();
      } else {
        this.alertWindow.show();
      }
    });
    this.alertWindow.on('closed', () => {
      this.alertWindow = null;
      this.clearCloseTimer();
    });

    this.closeTimer = setTimeout(() => {
      this.closeAlert();
    }, durationMs);
  }

  closeAlert() {
    this.clearCloseTimer();
    if (this.alertWindow && !this.alertWindow.isDestroyed()) {
      this.alertWindow.close();
    }
    this.alertWindow = null;
  }

  clearCloseTimer() {
    if (this.closeTimer) {
      clearTimeout(this.closeTimer);
      this.closeTimer = null;
    }
  }

  getWindowPosition(width, height) {
    const display = this.screen.getPrimaryDisplay();
    const { x, y, width: workWidth, height: workHeight } = display.workArea;
    const margin = 16;
    return {
      x: x + workWidth - width - margin,
      y: y + workHeight - height - margin,
    };
  }

  clamp(value, min, max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  computePopupSize({ title, body, copyCode }) {
    const text = `${title || ''}\n${body || ''}`;
    const textLen = text.length;

    let width = 360;
    if (textLen > 120) width = 420;
    if (textLen > 240) width = 480;

    const charsPerLine = Math.max(16, Math.floor((width - 40) / 8));
    const bodyLen = (body || '').length;
    const estimatedBodyLines = Math.max(
      1,
      Math.ceil(bodyLen / charsPerLine) + ((body || '').match(/\n/g) || []).length
    );

    let height = 112 + estimatedBodyLines * 22;
    if (copyCode) {
      height += 44;
    }

    return {
      width: this.clamp(width, 340, 500),
      height: this.clamp(height, 138, 320),
    };
  }

  parseCopyCode(url) {
    const prefix = 'sms-sync-copy://';
    if (!url || !url.startsWith(prefix)) {
      return null;
    }

    const encoded = url.slice(prefix.length);
    if (!encoded) {
      return null;
    }

    try {
      return decodeURIComponent(encoded);
    } catch (error) {
      return encoded;
    }
  }

  buildDataUrl(title, body, copyCode) {
    const safeTitle = escapeHtml(title);
    const safeBody = escapeHtml(body).replace(/\n/g, '<br>');
    const hasCode = typeof copyCode === 'string' && copyCode.length > 0;
    const encodedCode = hasCode ? encodeURIComponent(copyCode) : '';
    const actionHtml = hasCode
      ? `<button class="copy-btn" onclick="window.location.href='sms-sync-copy://${encodedCode}'">复制验证码</button>`
      : '';
    const html = `<!doctype html>
<html>
  <head>
    <meta charset="UTF-8" />
    <style>
      body {
        margin: 0;
        padding: 0;
        font-family: "Segoe UI", Arial, sans-serif;
        background: #111827;
        color: #f9fafb;
      }
      .card {
        width: 100%;
        box-sizing: border-box;
        border: 1px solid #1f2937;
        padding: 14px 16px;
        display: flex;
        flex-direction: column;
        gap: 10px;
      }
      .title {
        font-size: 16px;
        font-weight: 700;
        color: #fbbf24;
      }
      .body {
        font-size: 13px;
        line-height: 1.5;
        color: #e5e7eb;
        white-space: pre-wrap;
        word-break: break-word;
      }
      .hint {
        margin-top: auto;
        font-size: 12px;
        color: #9ca3af;
      }
      .copy-btn {
        margin-top: 4px;
        align-self: flex-start;
        background: #f59e0b;
        border: 0;
        color: #111827;
        padding: 8px 12px;
        border-radius: 6px;
        font-size: 12px;
        font-weight: 700;
        cursor: pointer;
      }
      .copy-btn:hover {
        background: #fbbf24;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="title">${safeTitle}</div>
      <div class="body">${safeBody}</div>
      ${actionHtml}
      <div class="hint">应用内通知，自动关闭</div>
    </div>
  </body>
</html>`;
    return `data:text/html;charset=UTF-8,${encodeURIComponent(html)}`;
  }
}

module.exports = {
  InAppAlertService,
};

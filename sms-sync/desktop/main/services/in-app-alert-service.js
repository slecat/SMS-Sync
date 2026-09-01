function escapeHtml(text = '') {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

class InAppAlertService {
  constructor({ BrowserWindow, screen, onCopyCode, onSystemNotification }) {
    this.BrowserWindow = BrowserWindow;
    this.screen = screen;
    this.onCopyCode = onCopyCode || (() => {});
    this.onSystemNotification = onSystemNotification || (() => {});
    this.alertWindow = null;
    this.closeTimer = null;
    this.alertToken = 0;
    this.currentWindowToken = 0;
    this.alertPayload = null;
  }

  showAlert({ title, body, durationMs = 12000, copyCode = null }) {
    const payload = { title: title || '', body: body || '', copyCode };
    this.alertPayload = payload;
    this.clearCloseTimer();
    const token = ++this.alertToken;
    this.currentWindowToken = token;

    if (!this.alertWindow || this.alertWindow.isDestroyed()) {
      this.alertWindow = this.createAlertWindow(payload, token);
    } else {
      this.loadAlert(payload, token);
    }

    this.closeTimer = setTimeout(() => {
      if (token === this.alertToken) this.closeAlert();
    }, Math.max(1000, Number(durationMs) || 12000));
  }

  createAlertWindow(payload, token) {
    const { width: popupWidth, height: popupHeight } = this.computePopupSize(payload);
    const { x, y } = this.getWindowPosition(popupWidth, popupHeight);
    const alertWindow = new this.BrowserWindow({
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
      backgroundColor: '#F4F1EB',
      webPreferences: { sandbox: true },
    });

    alertWindow.setMenuBarVisibility(false);
    alertWindow.setAlwaysOnTop(true, 'screen-saver');
    alertWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    alertWindow.webContents.on('will-navigate', (event, url) => {
      const code = this.parseCopyCode(url);
      if (!code) return;
      event.preventDefault();
      try {
        this.onCopyCode(code);
      } catch (error) {
        console.error('In-app alert copy failed:', error);
      } finally {
        this.closeAlert();
      }
    });
    alertWindow.webContents.on('did-fail-load', () => {
      if (this.alertWindow !== alertWindow) return;
      try {
        this.onSystemNotification(payload);
      } catch (error) {
        console.error('System notification fallback failed:', error);
      }
      this.closeAlert();
    });
    alertWindow.once('ready-to-show', () => {
      if (this.currentWindowToken !== token || this.alertWindow !== alertWindow) return;
      if (typeof alertWindow.showInactive === 'function') alertWindow.showInactive();
      else alertWindow.show();
    });
    alertWindow.on('closed', () => {
      if (this.alertWindow !== alertWindow) return;
      this.alertWindow = null;
      this.alertPayload = null;
      this.clearCloseTimer();
    });

    this.loadAlert(payload, token, alertWindow);
    return alertWindow;
  }

  loadAlert(payload, token, targetWindow = this.alertWindow) {
    if (!targetWindow || targetWindow.isDestroyed()) return;
    targetWindow.loadURL(this.buildDataUrl(payload.title, payload.body, payload.copyCode));
  }

  closeAlert() {
    this.alertToken += 1;
    this.clearCloseTimer();
    const window = this.alertWindow;
    this.alertWindow = null;
    this.alertPayload = null;
    this.currentWindowToken = 0;
    if (window && !window.isDestroyed()) window.close();
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
    return { x: x + workWidth - width - margin, y: y + workHeight - height - margin };
  }

  clamp(value, min, max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  computePopupSize({ title, body, copyCode }) {
    const text = `${title || ''}\n${body || ''}`;
    const width = this.clamp(text.length > 220 ? 460 : text.length > 100 ? 420 : 380, 360, 500);
    const charsPerLine = Math.max(18, Math.floor((width - 64) / 8));
    const estimatedBodyLines = Math.max(
      1,
      Math.ceil((body || '').length / charsPerLine) + ((body || '').match(/\n/g) || []).length
    );
    const height = 142 + estimatedBodyLines * 22 + (copyCode ? 48 : 0);
    return { width, height: this.clamp(height, 156, 360) };
  }

  parseCopyCode(url) {
    const prefix = 'sms-sync-copy://';
    if (!url || !url.startsWith(prefix)) return null;
    const encoded = url.slice(prefix.length);
    if (!encoded) return null;
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
      ? `<button class="copy-btn" type="button" onclick="window.location.href='sms-sync-copy://${encodedCode}'">复制验证码</button>`
      : '';
    const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'" />
    <style>
      :root { color-scheme: light; }
      * { box-sizing: border-box; }
      body { margin: 0; padding: 12px; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #F4F1EB; color: #173C36; }
      .card { width: 100%; min-height: 100%; padding: 18px 20px; border: 1px solid #DDD9D1; border-radius: 16px; background: #FFFDF9; box-shadow: 0 12px 32px rgba(23, 60, 54, .16); display: flex; flex-direction: column; gap: 10px; }
      .eyebrow { color: #6A7C76; font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; }
      .title { font-size: 17px; line-height: 1.3; font-weight: 700; }
      .body { color: #38534D; font-size: 14px; line-height: 1.55; white-space: pre-wrap; word-break: break-word; }
      .code { display: inline-block; padding: 8px 12px; border-radius: 10px; background: #E7F2EF; color: #173C36; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 20px; font-weight: 800; letter-spacing: .16em; }
      .actions { display: flex; align-items: center; gap: 10px; margin-top: 4px; }
      .copy-btn { border: 0; border-radius: 10px; padding: 9px 13px; background: #007F73; color: #FFFFFF; font-size: 13px; font-weight: 700; cursor: pointer; }
      .copy-btn:hover { background: #00665D; }
      .copy-btn:focus-visible { outline: 3px solid rgba(0, 127, 115, .28); outline-offset: 2px; }
      .hint { margin-left: auto; color: #7B8984; font-size: 11px; }
    </style>
  </head>
  <body>
    <main class="card" role="status" aria-live="polite" tabindex="-1">
      <div class="eyebrow">短信转发</div>
      <div class="title">${safeTitle}</div>
      <div class="body">${safeBody}</div>
      ${hasCode ? `<div class="code" aria-label="验证码">${escapeHtml(copyCode)}</div>` : ''}
      <div class="actions">${actionHtml}<div class="hint">按 Esc 关闭</div></div>
    </main>
    <script>window.addEventListener('keydown', (event) => { if (event.key === 'Escape') window.close(); });</script>
  </body>
</html>`;
    return `data:text/html;charset=UTF-8,${encodeURIComponent(html)}`;
  }
}

module.exports = { InAppAlertService };

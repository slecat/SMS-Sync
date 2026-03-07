const groupIdInput = document.getElementById('groupId');
const syncSecretInput = document.getElementById('syncSecret');
const serverUrlInput = document.getElementById('serverUrl');
const deviceNameInput = document.getElementById('deviceName');
const saveBtn = document.getElementById('saveBtn');
const autoLaunchToggle = document.getElementById('autoLaunchToggle');
const deviceListEl = document.getElementById('deviceList');
const messageList = document.getElementById('messageList');
const clearBtn = document.getElementById('clearBtn');
const smsCountEl = document.getElementById('smsCount');
const testCountEl = document.getElementById('testCount');
const messageCountEl = document.getElementById('messageCount');
const toast = document.getElementById('toast');
const serverStatus = document.getElementById('serverStatus');
const SERVER_URL_PREFIX = 'ws://';

const messages = [];
const MAX_MESSAGES = 300;
let smsCount = 0;
let testCount = 0;

function toggleSection(sectionName) {
  const header = document.querySelector(`[data-section="${sectionName}"]`);
  const wrapper = document.getElementById(`${sectionName}Content`);

  if (header && wrapper) {
    header.classList.toggle('collapsed');
    wrapper.classList.toggle('collapsed');
  }
}

document.querySelectorAll('.section-header').forEach((header) => {
  const sectionName = header.dataset.section;
  header.addEventListener('click', () => {
    toggleSection(sectionName);
  });
});

function showToast(message) {
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

function updateStats() {
  smsCountEl.textContent = smsCount;
  testCountEl.textContent = testCount;
  messageCountEl.textContent = `${messages.length} 条消息`;
}

function pushMessage(message) {
  messages.unshift(message);
  if (messages.length > MAX_MESSAGES) {
    messages.length = MAX_MESSAGES;
  }
}

function renderMessages() {
  if (messages.length === 0) {
    messageList.innerHTML = `
      <div class="empty-state">
        <div class="empty-icon">📱</div>
        <div class="empty-text">暂无消息，等待接收中...</div>
      </div>
    `;
    return;
  }

  messageList.innerHTML = '';
  messages.forEach((msg) => {
    const card = document.createElement('div');
    card.className = `message-card ${msg.type === 'test' ? 'test' : ''}`;

    const time = new Date(msg.timestamp).toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });

    const badgeClass = msg.type === 'test' ? 'badge-test' : 'badge-sms';
    const badgeText = msg.type === 'test' ? '测试' : '短信';

    card.innerHTML = `
      <div class="message-header-row">
        <div>
          <div class="message-sender">${msg.from}</div>
          <div class="message-time">${time}</div>
        </div>
        <span class="message-badge ${badgeClass}">${badgeText}</span>
      </div>
      <div class="message-body">${msg.body || '测试消息'}</div>
    `;
    messageList.appendChild(card);
  });
}

function renderDeviceList(devices) {
  if (devices.length === 0) {
    deviceListEl.innerHTML =
      '<div class="empty-devices">\u6682\u65e0\u5728\u7ebf\u8bbe\u5907</div>';
    return;
  }

  deviceListEl.innerHTML = '';
  devices.forEach((device) => {
    const sources = normalizeDeviceSources(device);
    const indicatorClass =
      sources.length > 1 ? 'mixed' : sources[0] === 'server' ? 'server' : 'lan';
    const sourceTags = sources
      .map(
        (source) =>
          `<span class="device-source-tag ${source}">${sourceLabel(source)}</span>`
      )
      .join('');

    const item = document.createElement('div');
    item.className = 'device-item';
    item.innerHTML = `
      <div class="device-indicator ${indicatorClass}"></div>
      <div class="device-name">${escapeHtml(device.deviceName || '\u672a\u77e5\u8bbe\u5907')}</div>
      <div class="device-sources">${sourceTags}</div>
    `;
    deviceListEl.appendChild(item);
  });
}

function normalizeDeviceSources(device) {
  if (Array.isArray(device.sources) && device.sources.length > 0) {
    const normalized = Array.from(
      new Set(device.sources.map((source) => (source === 'server' ? 'server' : 'lan')))
    );
    normalized.sort((a, b) => sourcePriority(a) - sourcePriority(b));
    return normalized;
  }
  return [device.source === 'server' ? 'server' : 'lan'];
}

function sourcePriority(source) {
  if (source === 'server') {
    return 0;
  }
  if (source === 'lan') {
    return 1;
  }
  return 2;
}

function sourceLabel(source) {
  return source === 'server' ? '\u670d\u52a1\u5668' : '\u5c40\u57df\u7f51';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function updateServerStatusUI(status, message) {
  if (!serverUrlInput.value) {
    serverStatus.style.display = 'none';
    return;
  }

  serverStatus.style.display = 'flex';
  serverStatus.className = `server-status ${status}`;
  serverStatus.querySelector('.status-text').textContent = message;
}

function stripServerProtocol(serverUrl) {
  const normalized = String(serverUrl || '').trim();
  if (!normalized) {
    return '';
  }

  return normalized.replace(/^[a-zA-Z][a-zA-Z\d+\-.]*:\/\//, '');
}

function toServerUrl(serverAddressInput) {
  const normalized = String(serverAddressInput || '').trim();
  if (!normalized) {
    return '';
  }

  const addressOnly = stripServerProtocol(normalized);
  return `${SERVER_URL_PREFIX}${addressOnly}`;
}

async function loadSettings() {
  const settings = await window.electronAPI.getSettings();
  groupIdInput.value = settings.groupId || 'default';
  syncSecretInput.value = settings.syncSecret || '';
  serverUrlInput.value = stripServerProtocol(settings.serverUrl || '');
  deviceNameInput.value = settings.deviceName || '桌面端';

  const autoLaunchEnabled = await window.electronAPI.getAutoLaunch();
  autoLaunchToggle.checked = autoLaunchEnabled;
}

async function loadServerStatus() {
  const status = await window.electronAPI.getServerStatus();
  if (status && status.status) {
    updateServerStatusUI(status.status, status.message || '');
  } else {
    updateServerStatusUI('disconnected', '未连接');
  }
}

async function loadDevices() {
  const devices = await window.electronAPI.getDevices();
  renderDeviceList(devices);
}

window.electronAPI.onServerStatusChange((status) => {
  updateServerStatusUI(status.status, status.message);
});

window.electronAPI.onDeviceListUpdate((devices) => {
  renderDeviceList(devices);
});

window.electronAPI.onNewSms((sms) => {
  pushMessage({
    ...sms,
    type: 'sms',
  });
  smsCount++;
  updateStats();
  renderMessages();
});

window.electronAPI.onNewTest((test) => {
  pushMessage({
    from: test.from,
    timestamp: test.timestamp,
    body: '测试消息',
    type: 'test',
  });
  testCount++;
  updateStats();
  renderMessages();
});

window.electronAPI.onCodeCopied((code) => {
  showToast(`验证码 ${code} 已复制到剪贴板`);
});

saveBtn.addEventListener('click', async () => {
  const syncSecret = syncSecretInput.value.trim();
  if (!syncSecret) {
    showToast('同步密钥不能为空');
    syncSecretInput.focus();
    return;
  }

  const settings = {
    groupId: groupIdInput.value || 'default',
    syncSecret,
    serverUrl: toServerUrl(serverUrlInput.value),
    deviceName: deviceNameInput.value || '桌面端',
  };
  const success = await window.electronAPI.saveSettings(settings);
  if (success) {
    showToast('设置已保存');
    return;
  }
  showToast('设置保存失败');
});

clearBtn.addEventListener('click', () => {
  messages.length = 0;
  smsCount = 0;
  testCount = 0;
  updateStats();
  renderMessages();
  showToast('消息已清空');
});

autoLaunchToggle.addEventListener('change', async () => {
  const success = await window.electronAPI.setAutoLaunch(autoLaunchToggle.checked);
  if (success) {
    showToast(autoLaunchToggle.checked ? '已开启开机自启动' : '已关闭开机自启动');
  } else {
    showToast('设置开机自启动失败');
    autoLaunchToggle.checked = !autoLaunchToggle.checked;
  }
});

async function initialize() {
  await loadSettings();
  await loadServerStatus();
  await loadDevices();
}

initialize();

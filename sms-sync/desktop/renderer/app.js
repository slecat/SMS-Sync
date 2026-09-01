const groupIdInput = document.getElementById('groupId');
const syncSecretInput = document.getElementById('syncSecret');
const serverUrlInput = document.getElementById('serverUrl');
const deviceNameInput = document.getElementById('deviceName');
const saveBtn = document.getElementById('saveBtn');
const forwardVerificationCodeOnlyToggle = document.getElementById(
  'forwardVerificationCodeOnlyToggle'
);
const autoLaunchToggle = document.getElementById('autoLaunchToggle');
const deviceListEl = document.getElementById('deviceList');
const messageList = document.getElementById('messageList');
const clearBtn = document.getElementById('clearBtn');
const smsCountEl = document.getElementById('smsCount');
const testCountEl = document.getElementById('testCount');
const messageCountEl = document.getElementById('messageCount');
const toast = document.getElementById('toast');
const serverStatus = document.getElementById('serverStatus');
const updateCurrentVersionEl = document.getElementById('updateCurrentVersion');
const updateStatusTextEl = document.getElementById('updateStatusText');
const updateLatestVersionEl = document.getElementById('updateLatestVersion');
const updateProgressRowEl = document.getElementById('updateProgressRow');
const updateProgressFillEl = document.getElementById('updateProgressFill');
const updateProgressTextEl = document.getElementById('updateProgressText');
const checkUpdateBtn = document.getElementById('checkUpdateBtn');
const downloadUpdateBtn = document.getElementById('downloadUpdateBtn');
const downloadRouteModalEl = document.getElementById('downloadRouteModal');
const downloadRouteBackdropEl = document.getElementById('downloadRouteBackdrop');
const downloadRouteListEl = document.getElementById('downloadRouteList');
const closeDownloadRouteBtn = document.getElementById('closeDownloadRouteBtn');
const SERVER_URL_PREFIX = 'ws://';

const messages = [];
const MAX_MESSAGES = 300;
let smsCount = 0;
let testCount = 0;
let currentUpdateState = null;
let downloadRouteSelectionResolver = null;

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
          <div class="message-sender">${escapeHtml(msg.from || '未知来源')}</div>
          <div class="message-time">${time}</div>
        </div>
        <span class="message-badge ${badgeClass}">${badgeText}</span>
      </div>
      <div class="message-body">${escapeHtml(msg.body || '测试消息')}</div>
    `;
    messageList.appendChild(card);
  });
}

function renderDeviceList(devices) {
  if (devices.length === 0) {
    deviceListEl.innerHTML = '<div class="empty-devices">暂无在线设备</div>';
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
      <div class="device-name">${escapeHtml(device.deviceName || '未知设备')}</div>
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
  return source === 'server' ? '服务器' : '局域网';
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

function formatVersionLabel(version, buildNumber) {
  const normalizedVersion = String(version || '').trim();
  const normalizedBuild = Number(buildNumber || 0);
  if (!normalizedVersion) {
    return '-';
  }
  if (normalizedBuild > 0) {
    return `v${normalizedVersion} (${normalizedBuild})`;
  }
  return `v${normalizedVersion}`;
}

function renderUpdateState(updateState) {
  const state = updateState || {};
  currentUpdateState = state;

  updateCurrentVersionEl.textContent = `当前版本 ${formatVersionLabel(
    state.currentVersion,
    state.currentBuildNumber
  )}`;

  if (state.latestRelease) {
    updateLatestVersionEl.textContent = `最新版本 ${formatVersionLabel(
      state.latestRelease.version,
      state.latestRelease.buildNumber
    )}`;
  } else {
    updateLatestVersionEl.textContent = '';
  }

  const status = state.status || 'idle';
  const statusText = {
    idle: '未检查更新',
    checking: '正在检查更新...',
    available: '发现新版本，可选择下载路线并安装',
    current: '当前已经是最新版本',
    downloading: '正在下载更新包...',
    ready: '安装包已下载，安装程序已启动',
    error: state.message || '检查更新失败',
  };

  updateStatusTextEl.textContent = statusText[status] || state.message || '未检查更新';
  checkUpdateBtn.disabled = status === 'checking' || status === 'downloading';

  const progress = Number(state.downloadProgress || 0);
  const showProgress = status === 'downloading' || progress > 0;
  updateProgressRowEl.classList.toggle('hidden', !showProgress);
  updateProgressFillEl.style.width = `${progress}%`;
  updateProgressTextEl.textContent = `${progress}%`;

  const shouldShowDownload =
    state.isUpdateAvailable && (status === 'available' || status === 'downloading');
  downloadUpdateBtn.classList.toggle('hidden', !shouldShowDownload);
  downloadUpdateBtn.disabled = status === 'checking' || status === 'downloading';
  downloadUpdateBtn.textContent = status === 'downloading' ? '下载中...' : '下载并安装';
}

function normalizeDownloadOptions(updateState) {
  const options = Array.isArray(updateState?.latestRelease?.downloadOptions)
    ? updateState.latestRelease.downloadOptions
    : [];
  return options.filter(
    (option) => option && typeof option.url === 'string' && option.url.trim()
  );
}

function closeDownloadRouteModal(selection = null) {
  if (downloadRouteSelectionResolver) {
    const resolver = downloadRouteSelectionResolver;
    downloadRouteSelectionResolver = null;
    resolver(selection);
  }

  downloadRouteListEl.innerHTML = '';
  downloadRouteModalEl.classList.add('hidden');
}

function promptDownloadRoute(options) {
  if (options.length === 1) {
    return Promise.resolve(options[0]);
  }

  downloadRouteListEl.innerHTML = '';
  options.forEach((option) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'route-option';
    button.innerHTML = `
      <div class="route-option-title">${escapeHtml(option.label || option.host || option.url)}</div>
      <div class="route-option-url">${escapeHtml(option.url)}</div>
    `;
    button.addEventListener('click', () => {
      closeDownloadRouteModal(option);
    });
    downloadRouteListEl.appendChild(button);
  });

  downloadRouteModalEl.classList.remove('hidden');
  return new Promise((resolve) => {
    downloadRouteSelectionResolver = resolve;
  });
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
  forwardVerificationCodeOnlyToggle.checked = Boolean(
    settings.forwardVerificationCodeOnly
  );

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

window.electronAPI.onUpdateStateChange((updateState) => {
  renderUpdateState(updateState);
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
    forwardVerificationCodeOnly: forwardVerificationCodeOnlyToggle.checked,
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

checkUpdateBtn.addEventListener('click', async () => {
  const updateState = await window.electronAPI.checkForUpdates();
  renderUpdateState(updateState);
  if (updateState.status === 'current') {
    showToast('当前已经是最新版本');
  } else if (updateState.status === 'available') {
    showToast('发现新版本，可以开始下载');
  } else if (updateState.status === 'error') {
    showToast(updateState.message || '检查更新失败');
  }
});

downloadUpdateBtn.addEventListener('click', async () => {
  const downloadOptions = normalizeDownloadOptions(currentUpdateState);
  let selectedOption = null;

  if (downloadOptions.length > 0) {
    selectedOption = await promptDownloadRoute(downloadOptions);
    if (!selectedOption) {
      return;
    }
  }

  const updateState = await window.electronAPI.downloadUpdate(selectedOption?.url);
  renderUpdateState(updateState);
  if (updateState.status === 'ready') {
    showToast('安装包已下载，正在启动安装程序');
  } else if (updateState.status === 'error') {
    showToast(updateState.message || '下载更新失败');
  }
});

downloadRouteBackdropEl.addEventListener('click', () => {
  closeDownloadRouteModal(null);
});

closeDownloadRouteBtn.addEventListener('click', () => {
  closeDownloadRouteModal(null);
});

async function initialize() {
  await loadSettings();
  await loadServerStatus();
  await loadDevices();
  renderUpdateState(await window.electronAPI.getUpdateState());
}

initialize();

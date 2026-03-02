const {
  app,
  BrowserWindow,
  ipcMain,
  Tray,
  Menu,
  nativeImage,
  clipboard,
  screen,
} = require('electron');
const path = require('path');
const crypto = require('crypto');
const Store = require('electron-store');
const AutoLaunch = require('auto-launch');
const WebSocket = require('ws');
const { registerIpcHandlers } = require('./ipc');
const { DeviceRegistry } = require('./services/device-registry');
const { signPayload, verifyPayload } = require('./services/message-security');
const {
  createMessageDeduper,
  extractVerificationCode,
} = require('./services/message-utils');
const { getIconPath } = require('./services/icon-path');
const { InAppAlertService } = require('./services/in-app-alert-service');
const { WebSocketClient } = require('./transport/websocket-client');
const { UdpService } = require('./transport/udp-service');

app.setAppUserModelId('com.smsforward.app');

const DEFAULT_SETTINGS = {
  serverUrl: '',
  groupId: 'default',
  deviceName: '桌面端',
  syncSecret: '',
};
const DEVICE_TIMEOUT = 30000;
const LISTEN_PORT = 8888;
const BROADCAST_PORTS = [8888, 8889];
const RECONNECT_PROBE_INTERVAL_MS = 5000;
const RECONNECT_PROBE_COOLDOWN_MS = 12000;

const store = new Store();
const autoLauncher = new AutoLaunch({ name: '短信转发', isHidden: true });
const desktopDeviceId = crypto.randomUUID();
const deviceRegistry = new DeviceRegistry({ deviceTimeout: DEVICE_TIMEOUT });
const isDuplicateMessage = createMessageDeduper(5000);
const state = {
  mainWindow: null,
  tray: null,
  isQuitting: false,
  startHiddenOnLaunch: false,
  localGroupId: DEFAULT_SETTINGS.groupId,
  localServerUrl: DEFAULT_SETTINGS.serverUrl,
  localDeviceName: DEFAULT_SETTINGS.deviceName,
  localSyncSecret: DEFAULT_SETTINGS.syncSecret,
  serverStatus: {
    status: 'disconnected',
    message: '未配置服务器地址',
  },
};

let cleanupTimer = null;
let reconnectProbeTimer = null;
let lastReconnectProbeAtMs = 0;
let wsClient = null;
let udpService = null;

const inAppAlertService = new InAppAlertService({
  BrowserWindow,
  screen,
  onCopyCode: (code) => {
    clipboard.writeText(code);
    if (state.mainWindow) {
      state.mainWindow.webContents.send('code-copied', code);
    }
  },
});

function createWindow() {
  const iconPath = getIconPath({ baseDir: __dirname });
  state.mainWindow = new BrowserWindow({
    width: 1000,
    height: 680,
    minWidth: 800,
    minHeight: 500,
    show: !state.startHiddenOnLaunch,
    autoHideMenuBar: true,
    icon: iconPath || undefined,
    webPreferences: {
      preload: path.join(__dirname, '..', 'preload.js'),
    },
  });

  state.mainWindow.loadFile(path.join(__dirname, '..', 'index.html'));
  state.mainWindow.on('close', (event) => {
    if (!state.isQuitting) {
      event.preventDefault();
      state.mainWindow.hide();
    }
  });
}

function showMainWindow() {
  if (!state.mainWindow) {
    return;
  }
  if (state.mainWindow.isMinimized()) {
    state.mainWindow.restore();
  }
  state.mainWindow.show();
  state.mainWindow.focus();
}

function quitApp() {
  state.isQuitting = true;
  app.quit();
}

function updateServerStatus(status, message) {
  state.serverStatus = { status, message };
  if (state.mainWindow) {
    state.mainWindow.webContents.send('server-status-change', { status, message });
  }
}

function updateDeviceList() {
  if (state.mainWindow) {
    state.mainWindow.webContents.send(
      'device-list-update',
      deviceRegistry.getCombinedDevices()
    );
  }
}

function connectToServer(serverUrl, trigger = 'unknown') {
  console.log(`[ServerStatus] connectToServer trigger=${trigger}`);
  wsClient.connect(serverUrl);
}

function handleSmsMessage(sms, source) {
  const dedupKey = sms.messageId || `sms_${sms.from}_${sms.body}`;
  if (isDuplicateMessage(dedupKey)) {
    return;
  }

  if (state.mainWindow) {
    state.mainWindow.webContents.send('new-sms', sms);
  }

  const code = extractVerificationCode(sms.body || '');
  triggerStrongAlert({
    title: code ? `验证码: ${code}` : `来自 ${sms.from}`,
    body: sms.body || '',
    copyCode: code,
    context: `sms:${source}`,
  });
}

function handleTestMessage(test, source) {
  const dedupKey = test.messageId || `test_${test.from}_${test.timestamp}`;
  if (isDuplicateMessage(dedupKey, 1000)) {
    return;
  }

  if (state.mainWindow) {
    state.mainWindow.webContents.send('new-test', test);
  }

  triggerStrongAlert({
    title: `测试消息 - ${test.from}`,
    body: '收到测试消息',
    durationMs: 6000,
    context: `test:${source}`,
  });
}

function handleLanDevicePresence(data) {
  const changed = deviceRegistry.updateLanPresence(data, desktopDeviceId);
  if (changed) {
    updateDeviceList();
  }
}

function handleServerDevicePresence(data) {
  const changed = deviceRegistry.updateServerPresence(data, desktopDeviceId);
  if (changed) {
    updateDeviceList();
  }
}

function hasSignatureFields(payload) {
  return Boolean(payload && (payload._sig || payload._sig_v));
}

function handleIncomingMessage(data, source) {
  if (data.groupId && data.groupId !== state.localGroupId) {
    return;
  }

  if (
    (data.type === 'sms' || data.type === 'test') &&
    !verifyPayload(data, state.localSyncSecret)
  ) {
    return;
  }

  if (data.type === 'sms') {
    handleSmsMessage(data, source);
  } else if (data.type === 'test') {
    handleTestMessage(data, source);
  } else if (data.type === 'device-presence') {
    if (hasSignatureFields(data) && !verifyPayload(data, state.localSyncSecret)) {
      return;
    }
    if (source === 'websocket') {
      handleServerDevicePresence(data);
    } else {
      handleLanDevicePresence(data);
    }
  }
}

function shouldUseStrongAlert() {
  return true;
}

function triggerStrongAlert({
  title,
  body,
  durationMs,
  copyCode = null,
  context = 'general',
}) {
  if (!shouldUseStrongAlert()) {
    return;
  }

  try {
    showInAppNotification({ title, body, durationMs, copyCode });
  } catch (error) {
    console.error(`Failed to show in-app alert (${context}):`, error);
  }
}

function showInAppNotification({ title, body, durationMs, copyCode = null }) {
  inAppAlertService.showAlert({ title, body, durationMs, copyCode });
}

function sendTestMessage(from = '桌面端') {
  const testData = signPayload(
    {
      type: 'test',
      from,
      timestamp: Date.now(),
      groupId: state.localGroupId,
    },
    state.localSyncSecret
  );

  try {
    udpService.sendOneShot(testData, LISTEN_PORT);
  } catch (error) {
    console.error('Local test broadcast failed:', error);
  }

  wsClient.send(testData);
}

function loadSettings() {
  const settings = store.get('settings', DEFAULT_SETTINGS);
  state.localGroupId = settings.groupId || DEFAULT_SETTINGS.groupId;
  state.localServerUrl = settings.serverUrl || DEFAULT_SETTINGS.serverUrl;
  state.localDeviceName = settings.deviceName || DEFAULT_SETTINGS.deviceName;
  state.localSyncSecret = settings.syncSecret || DEFAULT_SETTINGS.syncSecret;
  return settings;
}

function startCleanupLoop() {
  stopCleanupLoop();
  cleanupTimer = setInterval(() => {
    if (deviceRegistry.cleanup()) {
      updateDeviceList();
    }
  }, 5000);
}

function stopCleanupLoop() {
  if (cleanupTimer) {
    clearInterval(cleanupTimer);
    cleanupTimer = null;
  }
}

function startReconnectProbeLoop() {
  stopReconnectProbeLoop();
  reconnectProbeTimer = setInterval(() => {
    if (!state.localServerUrl) {
      return;
    }
    if (
      state.serverStatus.status === 'connected' ||
      state.serverStatus.status === 'connecting'
    ) {
      return;
    }
    const now = Date.now();
    if (now - lastReconnectProbeAtMs < RECONNECT_PROBE_COOLDOWN_MS) {
      return;
    }
    lastReconnectProbeAtMs = now;
    connectToServer(state.localServerUrl, 'heartbeat-probe');
  }, RECONNECT_PROBE_INTERVAL_MS);
}

function stopReconnectProbeLoop() {
  if (reconnectProbeTimer) {
    clearInterval(reconnectProbeTimer);
    reconnectProbeTimer = null;
  }
}

function setupTray() {
  const iconPath = getIconPath({ baseDir: __dirname });
  state.tray = iconPath ? new Tray(iconPath) : new Tray(nativeImage.createEmpty());

  const contextMenu = Menu.buildFromTemplate([
    { label: '显示主窗口', click: showMainWindow },
    { type: 'separator' },
    { label: '退出', click: quitApp },
  ]);

  state.tray.setToolTip('短信转发');
  state.tray.setContextMenu(contextMenu);
  state.tray.on('click', () => {
    if (state.mainWindow && state.mainWindow.isVisible()) {
      state.mainWindow.hide();
    } else {
      showMainWindow();
    }
  });
}

function hasHiddenStartupArg() {
  return process.argv.some((arg) => arg === '--hidden');
}

function wasOpenedAtLogin() {
  try {
    const settings = app.getLoginItemSettings();
    return Boolean(settings.wasOpenedAtLogin);
  } catch (error) {
    console.error('Get login item settings error:', error);
    return false;
  }
}

function shouldStartHiddenOnLaunch() {
  return hasHiddenStartupArg() || wasOpenedAtLogin();
}

async function refreshAutoLaunchEntry() {
  try {
    const enabled = await autoLauncher.isEnabled();
    if (enabled) {
      await autoLauncher.enable();
    }
  } catch (error) {
    console.error('Refresh auto launch entry error:', error);
  }
}

function initServices() {
  wsClient = new WebSocketClient({
    WebSocketImpl: WebSocket,
    onStatusChange: updateServerStatus,
    onMessage: (message) => handleIncomingMessage(message, 'websocket'),
    onDisconnected: () => {
      deviceRegistry.clearServer();
      updateDeviceList();
    },
    onError: (error) => console.error('WebSocket error:', error),
    onParseError: (error) => console.error('Invalid WebSocket payload:', error),
    getRegisterPayload: () => ({
      type: 'register',
      deviceId: desktopDeviceId,
      deviceName: state.localDeviceName,
      groupId: state.localGroupId,
    }),
    getHeartbeatPayload: () =>
      signPayload(
        {
          type: 'device-presence',
          deviceId: desktopDeviceId,
          deviceName: state.localDeviceName,
          groupId: state.localGroupId,
          timestamp: Date.now(),
        },
        state.localSyncSecret
      ),
  });

  udpService = new UdpService({
    listenPort: LISTEN_PORT,
    broadcastPorts: BROADCAST_PORTS,
    onMessage: handleIncomingMessage,
    onError: (error) => console.error('UDP error:', error),
  });
}

function cleanupServices() {
  stopCleanupLoop();
  stopReconnectProbeLoop();
  inAppAlertService.closeAlert();
  wsClient.disconnect();
  udpService.stop();
}

function registerHandlers() {
  registerIpcHandlers({
    ipcMain,
    getSettings: () => store.get('settings', DEFAULT_SETTINGS),
    getServerStatus: () => state.serverStatus,
    saveSettings: (event, settings) => {
      const normalizedSettings = {
        groupId: settings.groupId || DEFAULT_SETTINGS.groupId,
        serverUrl: settings.serverUrl || DEFAULT_SETTINGS.serverUrl,
        deviceName: settings.deviceName || DEFAULT_SETTINGS.deviceName,
        syncSecret: (settings.syncSecret || '').trim(),
      };
      if (!normalizedSettings.syncSecret) {
        return false;
      }

      store.set('settings', normalizedSettings);
      state.localGroupId = normalizedSettings.groupId;
      state.localServerUrl = normalizedSettings.serverUrl;
      state.localDeviceName = normalizedSettings.deviceName;
      state.localSyncSecret = normalizedSettings.syncSecret;
      connectToServer(normalizedSettings.serverUrl, 'manual-save-settings');
      return true;
    },
    sendTest: (event, from) => {
      sendTestMessage(from);
      return true;
    },
    getAutoLaunch: async () => {
      try {
        return await autoLauncher.isEnabled();
      } catch (error) {
        console.error('Get auto launch error:', error);
        return false;
      }
    },
    setAutoLaunch: async (event, enabled) => {
      try {
        if (enabled) {
          await autoLauncher.enable();
        } else {
          await autoLauncher.disable();
        }
        return true;
      } catch (error) {
        console.error('Set auto launch error:', error);
        return false;
      }
    },
    getDevices: () => deviceRegistry.getCombinedDevices(),
    minimizeToTray: () => {
      if (state.mainWindow) {
        state.mainWindow.hide();
      }
    },
    testNotification: () => {
      triggerStrongAlert({
        title: '测试通知',
        body: '这是一条测试通知消息！收到短信时会显示类似的通知。',
        durationMs: 6000,
        context: 'manual-test',
      });
    },
    testCodeNotification: (event, code) => {
      triggerStrongAlert({
        title: `验证码: ${code}`,
        body: `【某某应用】您的验证码是 ${code}，5分钟内有效。`,
        durationMs: 10000,
        copyCode: code,
        context: 'manual-code',
      });
    },
  });
}

function start() {
  initServices();
  registerHandlers();

  const gotTheLock = app.requestSingleInstanceLock();
  if (!gotTheLock) {
    app.quit();
    return;
  }

  app.on('second-instance', () => {
    if (state.mainWindow) {
      showMainWindow();
    }
  });

  app.whenReady().then(() => {
    state.startHiddenOnLaunch = shouldStartHiddenOnLaunch();
    createWindow();
    setupTray();
    refreshAutoLaunchEntry();

    const settings = loadSettings();
    connectToServer(settings.serverUrl, 'startup');
    startReconnectProbeLoop();
    udpService.start({
      getPresencePayload: () =>
        signPayload(
          {
            type: 'device-presence',
            deviceId: desktopDeviceId,
            deviceName: state.localDeviceName,
            groupId: state.localGroupId,
            timestamp: Date.now(),
          },
          state.localSyncSecret
        ),
    });
    startCleanupLoop();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      } else {
        showMainWindow();
      }
    });
  });

  app.on('before-quit', cleanupServices);
  app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
      // Keep app resident in tray on non-macOS.
    }
  });
}

module.exports = {
  start,
};

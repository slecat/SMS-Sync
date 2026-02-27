const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  getSettings: () => ipcRenderer.invoke('get-settings'),
  getServerStatus: () => ipcRenderer.invoke('get-server-status'),
  saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
  sendTest: (from) => ipcRenderer.invoke('send-test', from),
  onNewSms: (callback) => ipcRenderer.on('new-sms', (event, sms) => callback(sms)),
  onNewTest: (callback) => ipcRenderer.on('new-test', (event, test) => callback(test)),
  onCodeCopied: (callback) =>
    ipcRenderer.on('code-copied', (event, code) => callback(code)),
  onDeviceListUpdate: (callback) =>
    ipcRenderer.on('device-list-update', (event, devices) => callback(devices)),
  onServerStatusChange: (callback) =>
    ipcRenderer.on('server-status-change', (event, status) => callback(status)),
  minimizeToTray: () => ipcRenderer.send('minimize-to-tray'),
  testNotification: () => ipcRenderer.send('test-notification'),
  testCodeNotification: (code) => ipcRenderer.send('test-code-notification', code),
  getAutoLaunch: () => ipcRenderer.invoke('get-auto-launch'),
  setAutoLaunch: (enabled) => ipcRenderer.invoke('set-auto-launch', enabled),
  getDevices: () => ipcRenderer.invoke('get-devices'),
});

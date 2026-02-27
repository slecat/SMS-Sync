function registerIpcHandlers({
  ipcMain,
  getSettings,
  getServerStatus,
  saveSettings,
  sendTest,
  getAutoLaunch,
  setAutoLaunch,
  getDevices,
  minimizeToTray,
  testNotification,
  testCodeNotification,
}) {
  ipcMain.handle('get-settings', getSettings);
  ipcMain.handle('get-server-status', getServerStatus);
  ipcMain.handle('save-settings', saveSettings);
  ipcMain.handle('send-test', sendTest);
  ipcMain.handle('get-auto-launch', getAutoLaunch);
  ipcMain.handle('set-auto-launch', setAutoLaunch);
  ipcMain.handle('get-devices', getDevices);
  ipcMain.on('minimize-to-tray', minimizeToTray);
  ipcMain.on('test-notification', testNotification);
  ipcMain.on('test-code-notification', testCodeNotification);
}

module.exports = {
  registerIpcHandlers,
};

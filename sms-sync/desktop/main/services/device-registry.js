class DeviceRegistry {
  constructor({ deviceTimeout = 30000 } = {}) {
    this.deviceTimeout = deviceTimeout;
    this.lanDevices = new Map();
    this.serverDevices = new Map();
  }

  updateLanPresence(data, selfDeviceId) {
    if (!data || data.deviceId === selfDeviceId) {
      return false;
    }

    this.lanDevices.set(data.deviceId, {
      deviceId: data.deviceId,
      deviceName: data.deviceName || '未知设备',
      timestamp: data.timestamp,
      source: 'lan',
    });
    return true;
  }

  updateServerPresence(data, selfDeviceId) {
    if (!data || data.deviceId === selfDeviceId) {
      return false;
    }

    this.serverDevices.set(data.deviceId, {
      deviceId: data.deviceId,
      deviceName: data.deviceName || '未知设备',
      timestamp: data.timestamp,
      source: 'server',
    });
    return true;
  }

  clearServer() {
    if (this.serverDevices.size === 0) {
      return false;
    }
    this.serverDevices.clear();
    return true;
  }

  cleanup(now = Date.now()) {
    let changed = false;

    for (const [deviceId, device] of this.lanDevices) {
      if (now - device.timestamp > this.deviceTimeout) {
        this.lanDevices.delete(deviceId);
        changed = true;
      }
    }

    for (const [deviceId, device] of this.serverDevices) {
      if (now - device.timestamp > this.deviceTimeout) {
        this.serverDevices.delete(deviceId);
        changed = true;
      }
    }

    return changed;
  }

  getCombinedDevices() {
    const combinedDevices = new Map();

    for (const device of this.serverDevices.values()) {
      combinedDevices.set(device.deviceId, device);
    }

    for (const device of this.lanDevices.values()) {
      combinedDevices.set(device.deviceId, device);
    }

    return Array.from(combinedDevices.values());
  }
}

module.exports = {
  DeviceRegistry,
};

class DeviceRegistry {
  constructor({ deviceTimeout = 30000 } = {}) {
    this.deviceTimeout = deviceTimeout;
    this.lanDevices = new Map();
    this.serverDevices = new Map();
  }

  updateLanPresence(data, selfDeviceId, now = Date.now()) {
    return this.updatePresence(this.lanDevices, data, selfDeviceId, 'lan', now);
  }

  updateServerPresence(data, selfDeviceId, now = Date.now()) {
    return this.updatePresence(
      this.serverDevices,
      data,
      selfDeviceId,
      'server',
      now
    );
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

  updatePresence(store, data, selfDeviceId, source, now) {
    if (!data) {
      return false;
    }

    const deviceId = String(data.deviceId || '').trim();
    if (!deviceId || deviceId === selfDeviceId) {
      return false;
    }

    const normalizedName = String(data.deviceName || '').trim();
    const deviceName = normalizedName || '未知设备';
    const existing = store.get(deviceId);

    store.set(deviceId, {
      deviceId,
      deviceName,
      // Always use local receive time to avoid remote clock skew.
      timestamp: now,
      source,
    });

    if (!existing) {
      return true;
    }
    return existing.deviceName !== deviceName || existing.source !== source;
  }
}

module.exports = {
  DeviceRegistry,
};

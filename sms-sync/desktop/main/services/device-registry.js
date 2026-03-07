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
    return this.updatePresence(this.serverDevices, data, selfDeviceId, 'server', now);
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
    const sourcePriority = { server: 0, lan: 1 };

    const mergePresence = (device, source) => {
      const existing = combinedDevices.get(device.deviceId);
      if (!existing) {
        combinedDevices.set(device.deviceId, {
          ...device,
          source,
          sources: [source],
          sourceTimestamps: { [source]: device.timestamp },
        });
        return;
      }

      const sourceTimestamps = {
        ...(existing.sourceTimestamps || {}),
        [source]: device.timestamp,
      };
      const sources = Array.from(
        new Set([...(existing.sources || [existing.source]), source])
      ).sort((a, b) => {
        const left = sourcePriority[a] ?? 99;
        const right = sourcePriority[b] ?? 99;
        return left - right;
      });
      const preferredSource = sources.includes('lan') ? 'lan' : sources[0] || 'server';
      const preferredName =
        source === 'lan'
          ? device.deviceName || existing.deviceName
          : existing.deviceName || device.deviceName;

      combinedDevices.set(device.deviceId, {
        ...existing,
        ...device,
        deviceName: preferredName,
        source: preferredSource,
        sources,
        sourceTimestamps,
        timestamp: Math.max(existing.timestamp || 0, device.timestamp || 0),
      });
    };

    for (const device of this.serverDevices.values()) {
      mergePresence(device, 'server');
    }

    for (const device of this.lanDevices.values()) {
      mergePresence(device, 'lan');
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
    return existing.deviceName !== deviceName;
  }
}

module.exports = {
  DeviceRegistry,
};

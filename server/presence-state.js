function normalizeDeviceName(deviceName) {
  const normalizedName = String(deviceName || '').trim();
  return normalizedName || 'Unknown device';
}

function normalizeGroupId(groupId) {
  const normalizedGroupId = String(groupId || 'default').trim();
  return normalizedGroupId || 'default';
}

function buildPresencePayload({
  deviceId,
  deviceName,
  groupId,
  status = 'online',
  timestamp = Date.now(),
}) {
  return {
    type: 'device-presence',
    deviceId,
    deviceName: normalizeDeviceName(deviceName),
    groupId: normalizeGroupId(groupId),
    status,
    timestamp,
  };
}

function applyPresenceUpdate(clients, deviceId, data, now = Date.now()) {
  if (!deviceId || !clients.has(deviceId)) {
    return { removed: false, client: null };
  }

  const existing = clients.get(deviceId);
  const incomingName = String(data?.deviceName || '').trim();
  const client = {
    ...existing,
    deviceName: incomingName || existing.deviceName,
    lastSeenAt: now,
  };

  if (data?.status === 'offline') {
    clients.delete(deviceId);
    return { removed: true, client };
  }

  clients.set(deviceId, client);
  return { removed: false, client };
}

function removeClient(clients, deviceId, now = Date.now()) {
  if (!deviceId || !clients.has(deviceId)) {
    return null;
  }

  const client = clients.get(deviceId);
  clients.delete(deviceId);

  return buildPresencePayload({
    deviceId,
    deviceName: client.deviceName,
    groupId: client.groupId,
    status: 'offline',
    timestamp: now,
  });
}

module.exports = {
  applyPresenceUpdate,
  buildPresencePayload,
  removeClient,
};

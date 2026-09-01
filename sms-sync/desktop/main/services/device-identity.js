const crypto = require('node:crypto');

const DEVICE_IDENTITY_KEY = 'deviceIdentity';
const UUID_V4_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class DeviceIdentityService {
  constructor({ store, createUuid = () => crypto.randomUUID() }) {
    this.store = store;
    this.createUuid = createUuid;
  }

  getOrCreateIdentity() {
    const storedIdentity = this.store.get(DEVICE_IDENTITY_KEY);
    const storedDeviceId =
      storedIdentity && typeof storedIdentity === 'object'
        ? String(storedIdentity.deviceId || '').trim()
        : '';

    if (UUID_V4_PATTERN.test(storedDeviceId)) {
      return { deviceId: storedDeviceId };
    }

    const deviceId = this.createUuid();
    const identity = { deviceId };
    this.store.set(DEVICE_IDENTITY_KEY, identity);
    return identity;
  }

  createConnectionId() {
    return this.createUuid();
  }
}

module.exports = {
  DeviceIdentityService,
};

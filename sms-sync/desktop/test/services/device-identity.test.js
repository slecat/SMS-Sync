const test = require('node:test');
const assert = require('node:assert/strict');
const { DeviceIdentityService } = require('../../main/services/device-identity');

class FakeStore {
  constructor(initialState = {}) {
    this.state = { ...initialState };
  }

  get(key) {
    return this.state[key];
  }

  set(key, value) {
    this.state[key] = value;
  }
}

const uuidV4Pattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

test('DeviceIdentityService should reuse a persisted canonical device id', () => {
  const store = new FakeStore({
    deviceIdentity: {
      deviceId: '9ac0f2c2-6c22-447a-8e27-9d21e6d1049c',
    },
  });
  const service = new DeviceIdentityService({ store });

  const identity = service.getOrCreateIdentity();

  assert.equal(identity.deviceId, '9ac0f2c2-6c22-447a-8e27-9d21e6d1049c');
});

test('DeviceIdentityService should create and persist a canonical device id when missing', () => {
  const store = new FakeStore();
  const service = new DeviceIdentityService({ store });

  const identity = service.getOrCreateIdentity();

  assert.match(identity.deviceId, uuidV4Pattern);
  assert.equal(store.get('deviceIdentity').deviceId, identity.deviceId);
});

test('DeviceIdentityService should create runtime connection ids separate from device id', () => {
  const store = new FakeStore({
    deviceIdentity: {
      deviceId: '9ac0f2c2-6c22-447a-8e27-9d21e6d1049c',
    },
  });
  const service = new DeviceIdentityService({ store });

  const identity = service.getOrCreateIdentity();
  const connectionId = service.createConnectionId();

  assert.equal(identity.deviceId, '9ac0f2c2-6c22-447a-8e27-9d21e6d1049c');
  assert.match(connectionId, uuidV4Pattern);
  assert.notEqual(connectionId, identity.deviceId);
});

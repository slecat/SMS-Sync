const test = require('node:test');
const assert = require('node:assert/strict');
const { DeviceRegistry } = require('../../main/services/device-registry');

test('DeviceRegistry should ignore presence from current device', () => {
  const registry = new DeviceRegistry();

  const changed = registry.updateLanPresence(
    { deviceId: 'self', deviceName: 'self', timestamp: Date.now() },
    'self'
  );

  assert.equal(changed, false);
  assert.equal(registry.getCombinedDevices().length, 0);
});

test('DeviceRegistry should merge server and lan devices and prefer lan', () => {
  const now = Date.now();
  const registry = new DeviceRegistry();

  registry.updateServerPresence(
    { deviceId: 'dev-1', deviceName: 'from-server', timestamp: now },
    'self'
  );
  registry.updateLanPresence(
    { deviceId: 'dev-1', deviceName: 'from-lan', timestamp: now },
    'self'
  );

  const devices = registry.getCombinedDevices();
  assert.equal(devices.length, 1);
  assert.equal(devices[0].deviceName, 'from-lan');
  assert.equal(devices[0].source, 'lan');
});

test('DeviceRegistry should cleanup expired devices', () => {
  const now = Date.now();
  const registry = new DeviceRegistry({ deviceTimeout: 1000 });

  registry.updateLanPresence(
    { deviceId: 'dev-lan', deviceName: 'lan', timestamp: now - 1500 },
    'self',
    now - 1500
  );
  registry.updateServerPresence(
    { deviceId: 'dev-server', deviceName: 'server', timestamp: now },
    'self',
    now
  );

  const changed = registry.cleanup(now);
  assert.equal(changed, true);

  const devices = registry.getCombinedDevices();
  assert.equal(devices.length, 1);
  assert.equal(devices[0].deviceId, 'dev-server');
});

test('DeviceRegistry should treat timestamp-only refresh as unchanged', () => {
  const now = Date.now();
  const registry = new DeviceRegistry({ deviceTimeout: 1000 });

  const firstChanged = registry.updateServerPresence(
    { deviceId: 'dev-1', deviceName: 'server', timestamp: now },
    'self',
    now
  );
  const secondChanged = registry.updateServerPresence(
    { deviceId: 'dev-1', deviceName: 'server', timestamp: now + 500 },
    'self',
    now + 500
  );

  assert.equal(firstChanged, true);
  assert.equal(secondChanged, false);
});

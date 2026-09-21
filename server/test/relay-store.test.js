const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('fs')
const os = require('os')
const path = require('path')

const { createRelayStore } = require('../src/lib/relay-store')

test('queryMessages filters by type/group/device/keyword and limit', () => {
  const store = createRelayStore({ maxEvents: 20 })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-a',
    deviceName: 'A',
    phone: '13800000000',
    content: 'hello world',
    forwardedTo: ['dev-b'],
  })

  store.recordRelayEvent({
    type: 'test',
    groupId: 'g1',
    deviceId: 'dev-a',
    deviceName: 'A',
    content: 'ping',
    forwardedTo: ['dev-b'],
  })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g2',
    deviceId: 'dev-c',
    deviceName: 'C',
    content: 'hello outside',
    forwardedTo: ['dev-d'],
  })

  const result = store.queryMessages({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-a',
    keyword: 'hello',
    limit: 5,
  })

  assert.equal(result.total, 1)
  assert.equal(result.items.length, 1)
  assert.equal(result.items[0].type, 'sms')
  assert.equal(result.items[0].groupId, 'g1')
  assert.equal(result.items[0].deviceId, 'dev-a')
})

test('queryMessages supports exact phone/forwardedCount filters and returns facets', () => {
  const store = createRelayStore({ maxEvents: 20 })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-a',
    deviceName: 'A',
    phone: '13800000000',
    content: 'alpha',
    forwardedTo: ['dev-b', 'dev-c'],
  })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-b',
    deviceName: 'B',
    phone: '13900000000',
    content: 'beta',
    forwardedTo: [],
  })

  store.recordRelayEvent({
    type: 'test',
    groupId: 'g2',
    deviceId: 'dev-c',
    deviceName: 'C',
    phone: '13600000000',
    content: 'gamma',
    forwardedTo: ['dev-d'],
  })

  const result = store.queryMessages({
    type: 'sms',
    groupId: 'g1',
    phone: '13800000000',
    forwardedCount: 2,
    limit: 1,
  })

  assert.equal(result.total, 1)
  assert.equal(result.items.length, 1)
  assert.equal(result.items[0].deviceId, 'dev-a')
  assert.deepEqual(result.facets.types, ['sms'])
  assert.deepEqual(result.facets.groupIds, ['g1'])
  assert.deepEqual(result.facets.deviceIds, ['dev-a'])
  assert.deepEqual(result.facets.phones, ['13800000000'])
  assert.deepEqual(result.facets.forwardedCounts, [2])
})

test('queryMessages supports comma-separated multi-select filters', () => {
  const store = createRelayStore({ maxEvents: 20 })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-a',
    deviceName: 'A',
    phone: '13800000000',
    content: 'alpha',
    forwardedTo: ['dev-x'],
  })

  store.recordRelayEvent({
    type: 'test',
    groupId: 'g2',
    deviceId: 'dev-b',
    deviceName: 'B',
    phone: '13900000000',
    content: 'beta',
    forwardedTo: ['dev-y', 'dev-z'],
  })

  store.recordRelayEvent({
    type: 'sync',
    groupId: 'g3',
    deviceId: 'dev-c',
    deviceName: 'C',
    phone: '13700000000',
    content: 'gamma',
    forwardedTo: [],
  })

  const result = store.queryMessages({
    type: 'sms,test',
    groupId: 'g1,g2',
    deviceId: 'dev-a,dev-b',
    phone: '13800000000,13900000000',
    forwardedCount: '1,2',
    limit: 10,
  })

  assert.equal(result.total, 2)
  assert.deepEqual(
    result.items.map((item) => item.deviceId).sort(),
    ['dev-a', 'dev-b']
  )
})

test('getOverview and getGroupStats return aggregated metrics', () => {
  const store = createRelayStore({ maxEvents: 20 })
  const now = Date.now()

  store.upsertClient('dev-a', {
    groupId: 'g1',
    deviceName: 'Alpha',
    lastSeenAt: now,
  })
  store.upsertClient('dev-b', {
    groupId: 'g1',
    deviceName: 'Beta',
    lastSeenAt: now,
  })
  store.upsertClient('dev-c', {
    groupId: 'g2',
    deviceName: 'Gamma',
    lastSeenAt: now,
  })

  store.recordRelayEvent({
    type: 'sms',
    groupId: 'g1',
    deviceId: 'dev-a',
    content: 'm1',
    forwardedTo: ['dev-b'],
  })

  store.recordRelayEvent({
    type: 'test',
    groupId: 'g2',
    deviceId: 'dev-c',
    content: 'm2',
    forwardedTo: [],
  })

  const overview = store.getOverview()
  assert.equal(overview.onlineDevices, 3)
  assert.equal(overview.totalEvents, 2)
  assert.equal(overview.relayByType.sms, 1)
  assert.equal(overview.relayByType.test, 1)

  const groups = store.getGroupStats()
  const g1 = groups.find((item) => item.groupId === 'g1')
  const g2 = groups.find((item) => item.groupId === 'g2')

  assert.equal(g1.onlineDevices, 2)
  assert.equal(g1.relayEvents, 1)
  assert.equal(g2.onlineDevices, 1)
  assert.equal(g2.relayEvents, 1)
})

test('keeps only latest maxEvents', () => {
  const store = createRelayStore({ maxEvents: 2 })

  store.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'a', content: '1', forwardedTo: [] })
  store.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'a', content: '2', forwardedTo: [] })
  store.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'a', content: '3', forwardedTo: [] })

  const result = store.queryMessages({ limit: 10 })
  assert.equal(result.total, 2)
  assert.equal(result.items.length, 2)
  assert.equal(result.items[0].content, '3')
  assert.equal(result.items[1].content, '2')
})

test('clearMessages removes cached relay and system events', () => {
  const store = createRelayStore({ maxEvents: 20 })

  store.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'a', content: '1', forwardedTo: [] })
  store.recordSystemEvent({ type: 'register', groupId: 'g1', deviceId: 'a', content: 'online' })

  assert.equal(store.queryMessages({ limit: 10 }).total, 2)
  assert.equal(store.getOverview().totalEvents, 2)

  store.clearMessages()

  assert.equal(store.queryMessages({ limit: 10 }).total, 0)
  assert.equal(store.getOverview().totalEvents, 0)
  assert.deepEqual(store.queryMessages({ limit: 10 }).items, [])
})

test('relay events survive process restart through the persistence snapshot', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sms-sync-relay-'))
  const persistencePath = path.join(directory, 'events.json')
  const first = createRelayStore({ maxEvents: 20, persistencePath })
  first.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'a', content: 'durable', forwardedTo: [] })

  const second = createRelayStore({ maxEvents: 20, persistencePath })
  const result = second.queryMessages({ limit: 10 })
  assert.equal(result.total, 1)
  assert.equal(result.items[0].content, 'durable')
  fs.rmSync(directory, { recursive: true, force: true })
})

test('getReplay returns stable v2 SMS envelopes for reconnecting clients', () => {
  const store = createRelayStore({ maxEvents: 20 })
  store.recordRelayEvent({ type: 'sms', groupId: 'g1', deviceId: 'phone-1', phone: '95588', content: '验证码 123456', forwardedTo: [] })
  const replay = store.getReplay({ groupId: 'g1' })
  assert.equal(replay.length, 1)
  assert.equal(replay[0].protocolVersion, 2)
  assert.equal(replay[0].sourceDeviceId, 'phone-1')
})

const test = require('node:test')
const assert = require('node:assert/strict')

const {
  normalizeRegister,
  normalizeSms,
  normalizeAck,
  isMatchingAck,
  retryDelayMs,
} = require('../src/protocol/v2')

test('normalizes an sms envelope without dropping its stable id', () => {
  const envelope = normalizeSms({
    protocolVersion: 2,
    type: 'sms',
    messageId: 'm-1',
    groupId: 'g1',
    sourceDeviceId: 'phone-1',
    from: '95588',
    body: '验证码 482913',
    receivedAt: 1700000000000,
  })

  assert.equal(envelope.messageId, 'm-1')
  assert.equal(envelope.protocolVersion, 2)
  assert.equal(envelope.type, 'sms')
})

test('normalizes registration capabilities and platform', () => {
  const registration = normalizeRegister({
    type: 'register',
    protocolVersion: 2,
    deviceId: ' desktop-1 ',
    groupId: ' g1 ',
    deviceName: ' Office ',
    platform: 'DESKTOP',
    capabilities: ['replay', 'delivery-ack', 'replay'],
  })

  assert.deepEqual(registration, {
    type: 'register',
    protocolVersion: 2,
    deviceId: 'desktop-1',
    groupId: 'g1',
    deviceName: 'Office',
    platform: 'desktop',
    capabilities: ['delivery-ack', 'replay'],
  })
})

test('rejects an acknowledgement for a different message', () => {
  assert.equal(
    isMatchingAck(
      normalizeAck({ type: 'server-ack', messageId: 'm-1' }),
      { messageId: 'm-2' },
    ),
    false,
  )
})

test('retry delay follows the bounded delivery schedule', () => {
  assert.equal(retryDelayMs(1), 2000)
  assert.equal(retryDelayMs(6), 900000)
  assert.equal(retryDelayMs(99), 1800000)
})

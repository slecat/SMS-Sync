const test = require('node:test');
const assert = require('node:assert/strict');
const {
  signPayload,
  verifyPayload,
  SIGNATURE_KEY,
} = require('../../main/services/message-security');

test('signPayload should append signature fields when secret is provided', () => {
  const signed = signPayload(
    {
      type: 'sms',
      from: '10086',
      body: 'hello',
      groupId: 'default',
      timestamp: 1,
    },
    'abc123'
  );

  assert.equal(typeof signed[SIGNATURE_KEY], 'string');
  assert.equal(verifyPayload(signed, 'abc123'), true);
});

test('verifyPayload should fail when payload is tampered or secret mismatch', () => {
  const signed = signPayload(
    {
      type: 'test',
      from: 'desktop',
      groupId: 'default',
      timestamp: 2,
    },
    'abc123'
  );

  const tampered = { ...signed, from: 'attacker' };

  assert.equal(verifyPayload(tampered, 'abc123'), false);
  assert.equal(verifyPayload(signed, 'wrong-secret'), false);
});

test('verifyPayload should fail when secret is empty', () => {
  const signed = signPayload(
    {
      type: 'device-presence',
      deviceId: 'd1',
      groupId: 'default',
      timestamp: 3,
    },
    'abc123'
  );

  assert.equal(verifyPayload(signed, ''), false);
});

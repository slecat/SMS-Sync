const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeServerUrl } = require('../../main/services/server-url');

test('normalizeServerUrl should prepend ws protocol when missing', () => {
  assert.equal(normalizeServerUrl('127.0.0.1:3000'), 'ws://127.0.0.1:3000/');
});

test('normalizeServerUrl should keep ws url', () => {
  assert.equal(normalizeServerUrl('ws://localhost:3000'), 'ws://localhost:3000/');
});

test('normalizeServerUrl should keep secure ws url', () => {
  assert.equal(
    normalizeServerUrl('wss://server.example.com/sync'),
    'wss://server.example.com/sync'
  );
});

test('normalizeServerUrl should return empty string for invalid value', () => {
  assert.equal(normalizeServerUrl('not a valid host value'), '');
  assert.equal(normalizeServerUrl(''), '');
});

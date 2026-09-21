const test = require('node:test');
const assert = require('node:assert/strict');

const {
  UPDATE_API_BASE_URL,
  DESKTOP_UPDATE_SLUG,
} = require('../../main/services/update-config');

test('desktop update config points at the software download service', () => {
  assert.equal(UPDATE_API_BASE_URL, 'http://111.228.32.128:8002');
  assert.equal(DESKTOP_UPDATE_SLUG, 'sms-sync-desktop');
});

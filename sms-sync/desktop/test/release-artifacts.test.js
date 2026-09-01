const test = require('node:test');
const assert = require('node:assert/strict');
const packageMetadata = require('../package.json');

test('Windows release names identify setup and portable launchers', () => {
  assert.equal(packageMetadata.build.nsis.artifactName, 'sms-sync-desktop-${version}-setup.${ext}');
  assert.equal(packageMetadata.build.portable.artifactName, 'sms-sync-desktop-${version}-portable.${ext}');
});

test('Windows installer exposes a predictable post-install launch path', () => {
  assert.equal(packageMetadata.build.nsis.runAfterFinish, true);
  assert.equal(packageMetadata.build.nsis.createDesktopShortcut, true);
  assert.equal(packageMetadata.build.nsis.createStartMenuShortcut, true);
});

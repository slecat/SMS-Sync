const test = require('node:test');
const assert = require('node:assert/strict');

const desktopPackageJson = require('../../package.json');

test('desktop package config should point windows icon at build/icon.ico', () => {
  assert.equal(desktopPackageJson.build?.directories?.buildResources, 'build');
  assert.equal(desktopPackageJson.build?.win?.icon, 'build/icon.ico');
  assert.notEqual(desktopPackageJson.build?.win?.signAndEditExecutable, false);
});

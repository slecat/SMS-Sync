const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { getIconPath } = require('../../main/services/icon-path');

test('getIconPath should prefer desktop_icon in desktop directory', () => {
  const baseDir = path.join('C:', 'repo', 'desktop', 'main');
  const preferred = path.join(baseDir, '..', 'desktop_icon.png');
  const legacy = path.join(baseDir, '..', 'icon.png');
  const existing = new Set([preferred, legacy]);

  const result = getIconPath({
    baseDir,
    existsSync: (filePath) => existing.has(filePath),
  });

  assert.equal(result, preferred);
});

test('getIconPath should fallback to desktop_icon in repository root', () => {
  const baseDir = path.join('C:', 'repo', 'desktop', 'main');
  const fallback = path.join(baseDir, '..', '..', 'desktop_icon.png');

  const result = getIconPath({
    baseDir,
    existsSync: (filePath) => filePath === fallback,
  });

  assert.equal(result, fallback);
});

test('getIconPath should fallback to legacy icon when new icon is missing', () => {
  const baseDir = path.join('C:', 'repo', 'desktop', 'main');
  const legacy = path.join(baseDir, '..', 'icon.png');

  const result = getIconPath({
    baseDir,
    existsSync: (filePath) => filePath === legacy,
  });

  assert.equal(result, legacy);
});

test('getIconPath should return null when no icon file exists', () => {
  const result = getIconPath({
    baseDir: path.join('C:', 'repo', 'desktop', 'main'),
    existsSync: () => false,
  });

  assert.equal(result, null);
});

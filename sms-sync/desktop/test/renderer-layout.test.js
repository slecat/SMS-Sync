const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const desktopRoot = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(desktopRoot, file), 'utf8');

test('desktop workspace exposes mobile-aligned navigation and a two-column shell', () => {
  const markup = read('index.html');
  const styles = read('renderer/styles.css');

  assert.match(markup, /class="app-shell"/);
  assert.match(markup, /class="app-nav"/);
  assert.match(markup, /data-view="messages"/);
  assert.match(markup, /data-view="devices"/);
  assert.match(markup, /data-view="settings"/);
  assert.match(markup, /data-view="updates"/);
  assert.match(markup, /id="connectionSummary"/);
  assert.match(markup, /id="messageList"/);
  assert.doesNotMatch(markup, /📱/);
  assert.match(styles, /--surface: #F4F1EB/i);
  assert.match(styles, /--accent: #007F73/i);
  assert.match(styles, /grid-template-columns:\s*232px\s+minmax\(0, 1fr\)/i);
  assert.match(styles, /\.message-list[\s\S]*overflow-y:\s*auto/i);
});

test('desktop controls expose keyboard focus styling and responsive mobile fallback', () => {
  const styles = read('renderer/styles.css');
  assert.match(styles, /:focus-visible/);
  assert.match(styles, /@media\s*\(max-width:\s*760px\)/i);
  assert.match(styles, /grid-template-columns:\s*1fr/i);
});

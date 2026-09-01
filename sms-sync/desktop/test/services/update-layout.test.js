const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('desktop sidebar exposes updates as its own section', () => {
  const indexHtmlPath = path.join(__dirname, '..', '..', 'index.html');
  const markup = fs.readFileSync(indexHtmlPath, 'utf8');

  assert.match(markup, /class="updates-section"/);
  assert.match(markup, /data-section="updates"/);
  assert.match(markup, /id="updatesContent"/);
  assert.doesNotMatch(markup, /class="update-card"/);

  const devicesSectionIndex = markup.indexOf('class="devices-section"');
  const updatesSectionIndex = markup.indexOf('class="updates-section"');
  assert.notEqual(devicesSectionIndex, -1);
  assert.notEqual(updatesSectionIndex, -1);
  assert.ok(updatesSectionIndex > devicesSectionIndex);
});

test('desktop update panel includes a download route picker shell', () => {
  const indexHtmlPath = path.join(__dirname, '..', '..', 'index.html');
  const markup = fs.readFileSync(indexHtmlPath, 'utf8');

  assert.match(markup, /id="downloadRouteModal"/);
  assert.match(markup, /id="downloadRouteList"/);
  assert.match(markup, /id="closeDownloadRouteBtn"/);
  assert.match(markup, /默认安装包/);
  assert.match(markup, /镜像/);
});

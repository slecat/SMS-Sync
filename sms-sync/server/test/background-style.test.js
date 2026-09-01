const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const cssPath = path.join(__dirname, '..', 'public', 'styles.css')
const css = fs.readFileSync(cssPath, 'utf8')

test('uses Ops Console background tokens and body backdrop formula', () => {
  assert.match(css, /--bg:\s*#fff6ee;/)
  assert.match(css, /--bg-grid:\s*rgba\(217,\s*119,\s*6,\s*0\.05\);/)
  assert.match(css, /--bg-glow-a:\s*rgba\(251,\s*146,\s*60,\s*0\.28\);/)
  assert.match(css, /--bg-glow-b:\s*rgba\(244,\s*63,\s*94,\s*0\.2\);/)
  assert.match(css, /--bg-glow-c:\s*rgba\(250,\s*204,\s*21,\s*0\.22\);/)
  assert.match(
    css,
    /body\s*{[\s\S]*background:\s*[\s\S]*radial-gradient\(circle at 2% -30%,\s*var\(--bg-glow-a\),\s*transparent 41%\),[\s\S]*radial-gradient\(circle at 108% 24%,\s*var\(--bg-glow-b\),\s*transparent 35%\),[\s\S]*radial-gradient\(circle at 48% 114%,\s*var\(--bg-glow-c\),\s*transparent 47%\),[\s\S]*linear-gradient\(142deg,\s*transparent 0,\s*transparent 45%,\s*var\(--bg-grid\) 45%,\s*var\(--bg-grid\) 46%,\s*transparent 46%,\s*transparent 100%\),[\s\S]*var\(--bg\);/,
  )
})

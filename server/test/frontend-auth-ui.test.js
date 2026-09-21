const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const publicDir = path.join(__dirname, '..', 'public')

function read(fileName) {
  return fs.readFileSync(path.join(publicDir, fileName), 'utf8')
}

test('frontend app.js is syntactically valid', () => {
  const script = read('app.js')
  assert.doesNotThrow(() => {
    new vm.Script(script, { filename: 'public/app.js' })
  })
})

test('homepage exposes stable login-guide node ids used by script and css', () => {
  const js = read('app.js')
  const html = read('index.html')
  assert.equal(html.includes('id="authPanel"'), true, 'index.html should include authPanel')
  assert.equal(html.includes('id="authMessage"'), true, 'index.html should include authMessage')
  assert.equal(html.includes('id="gotoLoginBtn"'), true, 'index.html should include gotoLoginBtn')
  assert.equal(js.includes('authMessage'), true, 'app.js should reference authMessage')
  assert.equal(js.includes('gotoLoginBtn'), true, 'app.js should reference gotoLoginBtn')
})

test('homepage renders unified-login guide panel for unauthenticated users', () => {
  const html = read('index.html')
  assert.equal(html.includes('Admin Access'), true)
  assert.equal(html.includes('Ops SMS Sync Service Console'), true)
  assert.equal(html.includes('未检测到登录态，正在跳转统一登录...'), true)
  assert.equal(html.includes('前往 Ops Console 登录'), true)
})

test('homepage uses single-view rendering contract to prevent auth/dashboard overlap', () => {
  const html = read('index.html')
  const css = read('styles.css')
  const js = read('app.js')

  assert.equal(html.includes('class="shell" data-view="boot"'), true, 'shell should declare initial view state')
  assert.equal(html.includes('id="bootPanel" class="card boot-panel view-pane"'), true, 'boot panel should be a view pane')
  assert.equal(html.includes('id="authPanel" class="card auth-panel view-pane"'), true, 'auth panel should be a view pane')
  assert.equal(html.includes('id="dashboard" class="dashboard view-pane"'), true, 'dashboard should be a view pane')

  assert.equal(css.includes(".shell > .view-pane"), true, 'css should hide all panes by default')
  assert.equal(css.includes(".shell[data-view='boot'] #bootPanel"), true, 'css should show boot pane by state')
  assert.equal(css.includes(".shell[data-view='auth'] #authPanel"), true, 'css should show auth pane by state')
  assert.equal(css.includes(".shell[data-view='dashboard'] #dashboard"), true, 'css should show dashboard pane by state')

  assert.equal(js.includes('function setView(view)'), true, 'script should use centralized view-state switcher')
  assert.equal(js.includes('bootPanel.hidden'), false, 'script should not toggle bootPanel.hidden directly')
  assert.equal(js.includes('authPanel.hidden'), false, 'script should not toggle authPanel.hidden directly')
  assert.equal(js.includes('dashboard.hidden'), false, 'script should not toggle dashboard.hidden directly')
})

test('boot and auth views are centered in viewport', () => {
  const css = read('styles.css')
  assert.match(
    css,
    /\.shell\s*\{[\s\S]*min-height:\s*100vh[\s\S]*\}/,
    'shell should span full viewport height'
  )
  assert.match(
    css,
    /\.shell\[data-view='boot'\],\s*\.shell\[data-view='auth'\]\s*\{[\s\S]*align-content:\s*center[\s\S]*justify-items:\s*center[\s\S]*\}/,
    'boot/auth views should center content on both axes'
  )
})

test('message workspace keeps fixed height and uses inner scrolling', () => {
  const css = read('styles.css')
  assert.match(
    css,
    /\.message-workspace\s*\{[\s\S]*height:\s*clamp\([^)]+\)[\s\S]*min-height:\s*\d+px[\s\S]*\}/,
    'message workspace should keep a bounded fixed height'
  )
  assert.match(
    css,
    /\.message-workspace\s+\.message-table\s*\{[\s\S]*min-height:\s*0[\s\S]*\}/,
    'message table container should allow inner scroll area'
  )
  assert.match(
    css,
    /\.message-workspace\s+\.message-table\s+table\s*\{[\s\S]*min-width:\s*920px[\s\S]*table-layout:\s*fixed[\s\S]*\}/,
    'message table should keep readable min width and scroll horizontally when needed'
  )
})

test('message filters avoid squeeze by responsive auto-fit layout', () => {
  const html = read('index.html')
  const css = read('styles.css')
  const js = read('app.js')
  assert.equal(html.includes('id="filterForm"'), false, 'legacy form filter container should be removed')
  assert.equal(html.includes('id="keywordFilter"'), false, 'text keyword filter should be removed')
  assert.equal(html.includes('id="groupFilter"'), false, 'free-text group filter should be removed')
  assert.equal(html.includes('id="deviceFilter"'), false, 'free-text device filter should be removed')
  assert.equal(html.includes('id="workspaceFilterBar"'), true, 'workspace should expose select-only filter toolbar')
  assert.equal(html.includes('class="head-actions"'), true, 'workspace toolbar should be grouped into the panel header actions area')
  assert.equal(html.includes('id="columnFilterField"'), false, 'header-driven filtering should remove redundant current-column selector')
  assert.equal(html.includes('id="headerFilterPopover"'), false, 'header filtering should not render a detached popover panel')
  assert.equal(html.includes('id="headerFilterDropdown"'), true, 'workspace should expose a compact header dropdown shell')
  assert.equal(html.includes('id="headerFilterSelect"'), false, 'header filter should not rely on a native select that needs a second click')
  assert.equal(html.includes('id="headerFilterList"'), true, 'workspace should expose a direct option list for header filters')
  assert.equal(html.includes('id="activeFilterChips"'), false, 'workspace should remove top selected-filter chips summary')
  assert.equal(html.includes('id="messageCountTag"'), false, 'workspace header should remove message-count summary chip')
  assert.equal(html.includes('id="limitFilter"'), false, 'row-limit control should move into the table header dropdown instead of a top select')
  assert.equal(html.includes('class="quick-range"'), false, 'time-range shortcuts should move into the time header dropdown instead of a top button row')
  assert.equal(html.includes('手机号'), false, 'phone column should be removed from message workspace')
  assert.match(
    html,
    /data-filter-field="limit"[\s\S]*>序号</,
    'table should add a leading index column that doubles as the row-limit selector trigger'
  )
  assert.equal(html.includes('class="column-filter-btn"'), true, 'table headers should be clickable filter triggers')
  assert.equal(html.includes('class="column-filter-value"'), true, 'filterable headers should expose a small current-value indicator slot')
  assert.equal(html.includes('hidden></span>'), false, 'header current-value indicators should keep a stable slot instead of disappearing')
  assert.equal(html.includes('点击列头直接筛选'), false, 'redundant helper copy should be removed')
  assert.match(
    html,
    /class="head-actions"[\s\S]*id="lastUpdated"[\s\S]*id="workspaceFilterBar"[\s\S]*id="clearFiltersBtn"/,
    'header actions should be reduced to right-aligned last-updated text plus a compact clear-filters control'
  )
  assert.equal(html.includes('aria-label="清空消息"'), true, 'header icon button should clear messages instead of clearing filters')
  assert.equal(html.includes('title="清空消息"'), true, 'header icon button tooltip should describe clearing messages')
  assert.equal(js.includes('filterForm'), false, 'script should no longer depend on removed filter form')
  assert.equal(js.includes('columnFilterField'), false, 'script should not depend on removed current-column selector')
  assert.equal(js.includes('headerFilterSelect'), false, 'script should not depend on a native select for header filtering')
  assert.equal(js.includes('headerFilterList'), true, 'script should render and manage direct header list options')
  assert.equal(js.includes('headerFilterPopover'), false, 'script should no longer manage a detached popover panel')
  assert.equal(js.includes('openHeaderFilter'), true, 'script should open a header dropdown directly from column clicks')
  assert.equal(js.includes('fetchFieldOptions'), true, 'script should fetch self-excluded options for the active multi-select field')
  assert.equal(js.includes('const activeField = state.openField'), true, 'dropdown multi-select should keep track of the active field across refreshes')
  assert.equal(js.includes('await fetchFieldOptions(activeField)'), true, 'dropdown multi-select should refetch self-excluded options after each selection')
  assert.equal(js.includes('mergeFieldOptions'), true, 'script should merge async field options with current local options to avoid dropdown flicker and empty states')
  assert.equal(js.includes('buildFieldOptionsFromFacets(state.availableFilterOptions)'), true, 'opening a field should snapshot current options so the dropdown does not oscillate between two datasets')
  assert.equal(js.includes('[field]: mergeFieldOptions('), true, 'async field option refresh should update only the active field snapshot instead of replacing the whole dropdown source')
  assert.equal(js.includes('overrideOptions ||'), false, 'script should not blindly replace local options with async field options')
  assert.equal(js.includes("values.join(',')"), false, 'multi-select filters should not be serialized as one comma-joined value')
  assert.equal(js.includes('query.append(config.queryKey, value)'), true, 'multi-select filters should append one query param per selected value')
  assert.equal(js.includes("api('/api/relay/messages/clear'"), true, 'clear button should call the clear-messages api')
  assert.equal(js.includes('buildDeviceLabelMap'), true, 'script should build a device-id to device-name lookup for filter labels')
  assert.equal(js.includes('buildDeviceOptionLabel'), true, 'device filter labels should use one stable formatter instead of switching between raw ids and names')
  assert.equal(js.includes("deviceLabel === normalizedDeviceId"), true, 'device filter labels should avoid duplicate text when the name already equals the id')
  assert.equal(js.includes("`${deviceLabel} · ${normalizedDeviceId}`"), true, 'device filter labels should include both name and id when available so same-name devices do not look duplicated')
  assert.equal(js.includes("field === 'limit'"), true, 'script should treat the index-column dropdown as the row-limit selector')
  assert.equal(js.includes("field === 'timestamp'"), true, 'script should treat the time column as a dedicated time-range dropdown')
  assert.equal(js.includes("querySelectorAll('.range-btn')"), false, 'script should no longer depend on top-level time-range buttons')
  assert.equal(js.includes('messageCountTag'), false, 'script should stop rendering the removed message-count chip')
  assert.equal(js.includes('limitFilter?.addEventListener'), false, 'script should stop depending on the removed top limit select')
  assert.equal(js.includes('focusRangeControl'), false, 'time header should open a dropdown instead of redirecting focus to an external control')
  assert.equal(js.includes('buildAvailableFilterOptions'), true, 'script should build filter options from dashboard datasets, not only message facets')
  assert.equal(js.includes('updateColumnFilterIndicators'), true, 'script should update small current-value labels in the table headers')
  assert.equal(js.includes('toggleFilterValue'), true, 'script should support multi-select toggling within the header dropdown')
  assert.equal(js.includes('groups.map'), true, 'script should merge group options from group stats')
  assert.equal(js.includes('devices.map'), true, 'script should merge device options from device list')
  assert.equal(js.includes("querySelectorAll('.column-filter-btn')"), true, 'script should bind header click filters')
  assert.match(
    css,
    /\.workspace-filter-bar\s*\{[\s\S]*display:\s*flex[\s\S]*justify-content:\s*flex-end[\s\S]*\}/,
    'clear-filter toolbar should stay compact and anchored to the far right'
  )
  assert.match(
    css,
    /\.head-actions\s*\{[\s\S]*display:\s*flex[\s\S]*justify-content:\s*flex-end[\s\S]*\}/,
    'panel header actions should collapse to the right side instead of reserving a wide utility row'
  )
  assert.match(
    css,
    /\.head-meta\s*\{[\s\S]*justify-content:\s*flex-end[\s\S]*text-align:\s*right[\s\S]*\}/,
    'last-updated text should be right-aligned and compact'
  )
  assert.match(
    css,
    /\.header-filter-dropdown\s*\{[\s\S]*position:\s*absolute[\s\S]*z-index:\s*\d+[\s\S]*\}/,
    'header filter should be rendered as an anchored dropdown instead of a block panel'
  )
  assert.match(
    css,
    /\.header-filter-option\s*\{[\s\S]*display:\s*flex[\s\S]*justify-content:\s*space-between[\s\S]*width:\s*100%[\s\S]*\}/,
    'header dropdown should render immediate clickable options instead of a second expand control'
  )
  assert.match(
    css,
    /\.header-filter-list\s*\{[\s\S]*max-height:\s*\d+px[\s\S]*overflow:\s*auto[\s\S]*\}/,
    'header dropdown list should remain scrollable for multi-select option sets'
  )
  assert.match(
    css,
    /\.header-filter-option\.is-active\s*\{[\s\S]*\}/,
    'multi-select options should expose an active visual state'
  )
  assert.match(
    css,
    /\.column-filter-btn\s*\{[\s\S]*display:\s*grid[\s\S]*grid-template-columns:\s*minmax\(0,\s*1fr\)\s+\d+px[\s\S]*width:\s*100%[\s\S]*\}/,
    'header button should use a fixed label/value layout so spacing does not jump'
  )
  assert.equal(
    css.includes('.column-filter-btn.is-filtered::after'),
    false,
    'header buttons should not inject extra marker width that makes columns jump'
  )
  assert.match(
    css,
    /\.column-filter-value\s*\{[\s\S]*min-width:\s*\d+px[\s\S]*max-width:\s*\d+px[\s\S]*text-overflow:\s*ellipsis[\s\S]*\}/,
    'header current-value indicator should keep a stable width and truncate long values'
  )
  assert.equal(css.includes('.message-workspace th:nth-child(1) { width: 92px; }'), true, 'index column should reserve fixed space for row-limit indicator and row numbers')
  assert.equal(css.includes('.message-workspace th:nth-child(6) { width: 260px; }'), true, 'content column should be constrained even after removing the phone column')
  assert.equal(css.includes('.message-workspace th:nth-child(7) { width: 108px; }'), true, 'forwarded-count column should keep a dedicated stable width')
  assert.match(
    css,
    /\.icon-btn\s*\{[\s\S]*width:\s*\d+px[\s\S]*height:\s*\d+px[\s\S]*\}/,
    'clear-filters control should render as a compact icon button'
  )
  assert.equal(js.includes("value = '全部'"), true, 'header indicator should show 全部 when no filter is selected')
})

test('insight panels keep bounded height and rely on inner scrolling', () => {
  const html = read('index.html')
  const css = read('styles.css')

  assert.equal(html.includes('class="card panel insight-panel"'), true, 'group/device cards should opt into bounded insight panel layout')
  assert.equal(html.includes('class="table-wrap compact-table panel-scroll"'), true, 'group panel should scroll inside panel body')
  assert.equal(html.includes('class="panel-scroll device-scroll"'), true, 'device panel should scroll inside panel body')
  assert.match(
    css,
    /\.insight-panel\s*\{[\s\S]*height:\s*clamp\([^)]+\)[\s\S]*min-height:\s*\d+px[\s\S]*\}/,
    'insight panel should keep a bounded fixed height'
  )
  assert.match(
    css,
    /\.insight-panel\s+\.panel-scroll\s*\{[\s\S]*min-height:\s*0[\s\S]*overflow:\s*auto[\s\S]*\}/,
    'insight panel body should scroll internally instead of stretching the card'
  )
})

test('insight row is above message workspace and shares one row', () => {
  const html = read('index.html')
  const css = read('styles.css')

  const insightIndex = html.indexOf('class="insight-row"')
  const messageIndex = html.indexOf('class="card panel message-workspace"')
  assert.equal(insightIndex > -1, true, 'insight row container should exist')
  assert.equal(messageIndex > -1, true, 'message workspace should exist')
  assert.equal(insightIndex < messageIndex, true, 'insight row should be rendered above message workspace')

  assert.match(
    css,
    /\.workspace-grid\s*\{[\s\S]*grid-template-columns:\s*1fr[\s\S]*\}/,
    'workspace should place message workspace on its own row'
  )
  assert.match(
    css,
    /\.insight-row\s*\{[\s\S]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)[\s\S]*\}/,
    'group and device panels should share one row'
  )
})

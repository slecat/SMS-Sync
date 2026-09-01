const shell = document.querySelector('.shell')
const authMessage = document.getElementById('authMessage')
const gotoLoginBtn = document.getElementById('gotoLoginBtn')

const columnFilterButtons = [...document.querySelectorAll('.column-filter-btn')]
const columnFilterIndicators = [...document.querySelectorAll('.column-filter-value')]
const messageWorkspace = document.querySelector('.message-workspace')
const clearFiltersBtn = document.getElementById('clearFiltersBtn')
const headerFilterDropdown = document.getElementById('headerFilterDropdown')
const headerFilterList = document.getElementById('headerFilterList')

const metricOnline = document.getElementById('metricOnline')
const metricGroups = document.getElementById('metricGroups')
const metricEvents = document.getElementById('metricEvents')
const metricForwarded = document.getElementById('metricForwarded')
const lastUpdated = document.getElementById('lastUpdated')

const groupBody = document.getElementById('groupBody')
const groupEmpty = document.getElementById('groupEmpty')
const deviceList = document.getElementById('deviceList')
const deviceEmpty = document.getElementById('deviceEmpty')
const deviceCountTag = document.getElementById('deviceCountTag')
const messageBody = document.getElementById('messageBody')
const messageEmpty = document.getElementById('messageEmpty')

const FILTER_FIELDS = Object.freeze({
  type: {
    label: '类型',
    queryKey: 'type',
    facetKey: 'types',
    allLabel: '全部类型',
  },
  groupId: {
    label: 'Group',
    queryKey: 'groupId',
    facetKey: 'groupIds',
    allLabel: '全部分组',
  },
  deviceId: {
    label: '设备',
    queryKey: 'deviceId',
    facetKey: 'deviceIds',
    allLabel: '全部设备',
  },
  forwardedCount: {
    label: '转发',
    queryKey: 'forwardedCount',
    facetKey: 'forwardedCounts',
    allLabel: '全部转发次数',
  },
})

const RANGE_PRESETS = {
  all: { label: '全部时间', durationMs: null },
  '5m': { label: '近5分钟', durationMs: 5 * 60 * 1000 },
  '1h': { label: '近1小时', durationMs: 60 * 60 * 1000 },
  '24h': { label: '近24小时', durationMs: 24 * 60 * 60 * 1000 },
}
const LIMIT_OPTIONS = Object.freeze(['50', '100', '200'])

const VIEW = Object.freeze({
  boot: 'boot',
  auth: 'auth',
  dashboard: 'dashboard',
})

const state = {
  user: null,
  timer: null,
  loginTimer: null,
  loading: false,
  rangePreset: 'all',
  redirecting: false,
  openField: '',
  filters: {
    limit: '50',
    values: {
      type: [],
      groupId: [],
      deviceId: [],
      forwardedCount: [],
    },
  },
  availableFilterOptions: createEmptyFacets(),
  deviceLabelMap: {},
  openFieldOptions: null,
  messageResult: createEmptyMessageResult(),
}

function createEmptyFacets() {
  return {
    types: [],
    groupIds: [],
    deviceIds: [],
    phones: [],
    forwardedCounts: [],
  }
}

function createEmptyMessageResult() {
  return {
    total: 0,
    limit: 0,
    offset: 0,
    facets: createEmptyFacets(),
    items: [],
  }
}

function createEmptyFieldOptions() {
  return {
    type: [],
    groupId: [],
    deviceId: [],
    forwardedCount: [],
  }
}

function buildAvailableFilterOptions({ groups = [], devices = [], messageResult = null } = {}) {
  const next = createEmptyFacets()
  const facets = messageResult?.facets || createEmptyFacets()

  const mergedGroupIds = new Set([
    ...groups.map((group) => String(group?.groupId || '').trim()).filter(Boolean),
    ...facets.groupIds.map((groupId) => String(groupId || '').trim()).filter(Boolean),
  ])
  const mergedDeviceIds = new Set([
    ...devices.map((device) => String(device?.deviceId || '').trim()).filter(Boolean),
    ...facets.deviceIds.map((deviceId) => String(deviceId || '').trim()).filter(Boolean),
  ])

  next.types = [...facets.types]
  next.groupIds = [...mergedGroupIds]
  next.deviceIds = [...mergedDeviceIds]
  next.phones = [...facets.phones]
  next.forwardedCounts = [...facets.forwardedCounts]

  return next
}

function buildFieldOptionsFromFacets(facets = createEmptyFacets()) {
  return {
    type: [...(facets.types || [])].map((value) => String(value)),
    groupId: [...(facets.groupIds || [])].map((value) => String(value)),
    deviceId: [...(facets.deviceIds || [])].map((value) => String(value)),
    forwardedCount: [...(facets.forwardedCounts || [])].map((value) => String(value)),
  }
}

function buildDeviceLabelMap({ devices = [], messageResult = null } = {}) {
  const map = {}

  for (const device of devices) {
    const deviceId = String(device?.deviceId || '').trim()
    if (!deviceId) continue
    map[deviceId] = String(device?.deviceName || deviceId).trim() || deviceId
  }

  const items = Array.isArray(messageResult?.items) ? messageResult.items : []
  for (const item of items) {
    const deviceId = String(item?.deviceId || '').trim()
    if (!deviceId) continue
    map[deviceId] = String(item.deviceName || item.deviceId).trim() || deviceId
  }

  return map
}

function buildDeviceOptionLabel(deviceId) {
  const normalizedDeviceId = String(deviceId || '').trim()
  if (!normalizedDeviceId) return '-'

  const deviceLabel = String(state.deviceLabelMap[normalizedDeviceId] || '').trim()
  if (!deviceLabel || deviceLabel === normalizedDeviceId) {
    return normalizedDeviceId
  }

  return `${deviceLabel} · ${normalizedDeviceId}`
}

function formatTime(timestamp) {
  if (!timestamp) return '-'
  return new Date(timestamp).toLocaleString('zh-CN', { hour12: false })
}

function formatDeviceStatus(status) {
  return status === 'offline' ? 'offline' : 'online'
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function formatFilterValue(field, value) {
  if (field === 'deviceId') {
    return buildDeviceOptionLabel(value)
  }

  if (field === 'forwardedCount') {
    return `${value} 次`
  }
  return String(value)
}

function formatFilterSummary(field, values) {
  if (!Array.isArray(values) || values.length === 0) {
    return '全部'
  }

  if (values.length === 1) {
    return formatFilterValue(field, values[0])
  }

  return `${values.length}项`
}

function formatRangeSummary() {
  if (state.rangePreset === 'all') {
    return '全部'
  }

  return (RANGE_PRESETS[state.rangePreset] || RANGE_PRESETS.all).label
}

function formatLimitSummary() {
  return String(state.filters.limit || '50')
}

function buildStaticHeaderOptions(field) {
  if (field === 'limit') {
    return LIMIT_OPTIONS.map((value) => ({
      value,
      label: `${value}条`,
      active: String(state.filters.limit) === String(value),
    }))
  }

  if (field === 'timestamp') {
    return Object.entries(RANGE_PRESETS).map(([value, preset]) => ({
      value,
      label: value === 'all' ? '全部时间' : preset.label,
      active: state.rangePreset === value,
    }))
  }

  return []
}

function mergeFieldOptions(field, baseOptions = [], fetchedOptions = [], currentValues = []) {
  const merged = new Set()

  for (const value of baseOptions) {
    const normalized = String(value || '')
    if (normalized) merged.add(normalized)
  }

  for (const value of fetchedOptions) {
    const normalized = String(value || '')
    if (normalized) merged.add(normalized)
  }

  for (const value of currentValues) {
    const normalized = String(value || '')
    if (normalized) merged.add(normalized)
  }

  return sortFacetValues(field, [...merged])
}

function sortFacetValues(field, values) {
  if (field === 'forwardedCount') {
    return [...values].sort((a, b) => Number(a) - Number(b))
  }

  return [...values].sort((a, b) =>
    String(a).localeCompare(String(b), 'zh-CN', { numeric: true, sensitivity: 'base' })
  )
}

function getFilterValues(field) {
  return Array.isArray(state.filters.values[field]) ? state.filters.values[field] : []
}

function setFilterValues(field, values) {
  if (!FILTER_FIELDS[field]) return
  state.filters.values[field] = [...new Set(values.map((item) => String(item)).filter(Boolean))]
}

function toggleFilterValue(field, value) {
  if (!FILTER_FIELDS[field]) return
  const normalizedValue = String(value || '')
  if (!normalizedValue) {
    setFilterValues(field, [])
    return
  }

  const currentValues = getFilterValues(field)
  if (currentValues.includes(normalizedValue)) {
    setFilterValues(
      field,
      currentValues.filter((item) => item !== normalizedValue)
    )
    return
  }

  setFilterValues(field, [...currentValues, normalizedValue])
}

function resetColumnFilters() {
  for (const field of Object.keys(FILTER_FIELDS)) {
    state.filters.values[field] = []
  }
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    credentials: 'include',
    ...options,
    headers: {
      'content-type': 'application/json',
      ...(options.headers || {}),
    },
  })

  const body = await response.json().catch(() => ({}))
  if (!response.ok || body.success === false) {
    const message = body.error || `请求失败(${response.status})`
    const error = new Error(message)
    error.status = response.status
    throw error
  }

  return body
}

function setView(view) {
  if (!shell) return
  shell.dataset.view = view
}

function setAuthMessage(message) {
  authMessage.textContent = message
}

function clearLoginRedirect() {
  if (!state.loginTimer) return
  window.clearTimeout(state.loginTimer)
  state.loginTimer = null
}

function buildMessageQuery() {
  return buildMessageQueryExcludingField('')
}

function buildMessageQueryExcludingField(excludedField) {
  const query = new URLSearchParams()
  query.set('limit', state.filters.limit)

  for (const [field, config] of Object.entries(FILTER_FIELDS)) {
    if (field === excludedField) continue
    const values = getFilterValues(field)
    if (values.length === 0) continue
    for (const value of values) {
      query.append(config.queryKey, value)
    }
  }

  const preset = RANGE_PRESETS[state.rangePreset] || RANGE_PRESETS.all
  if (preset.durationMs) {
    const now = Date.now()
    query.set('since', String(now - preset.durationMs))
    query.set('until', String(now))
  }

  return query.toString()
}

async function fetchFieldOptions(field) {
  if (!FILTER_FIELDS[field] || !state.user) return

  const query = buildMessageQueryExcludingField(field)
  const response = await api(`/api/relay/messages${query ? `?${query}` : ''}`)
  const fetchedOptions = buildFieldOptionsFromFacets(response?.data?.facets || createEmptyFacets())
  const currentFieldOptions =
    state.openFieldOptions && Array.isArray(state.openFieldOptions[field])
      ? state.openFieldOptions[field]
      : []

  state.openFieldOptions = {
    ...(state.openFieldOptions || createEmptyFieldOptions()),
    [field]: mergeFieldOptions(
      field,
      currentFieldOptions,
      fetchedOptions[field] || [],
      getFilterValues(field)
    ),
  }
}

function closeHeaderFilter() {
  state.openField = ''
  if (headerFilterDropdown) {
    headerFilterDropdown.hidden = true
  }
  updateColumnFilterButtons()
}

function updateColumnFilterIndicators() {
  for (const indicator of columnFilterIndicators) {
    const field = indicator.dataset.filterIndicator || ''
    let value = '全部'

    if (field === 'limit') {
      value = formatLimitSummary()
    } else if (field === 'timestamp') {
      value = formatRangeSummary()
    } else if (FILTER_FIELDS[field]) {
      value = formatFilterSummary(field, getFilterValues(field))
    }

    indicator.textContent = value
  }
}

function updateColumnFilterButtons() {
  for (const button of columnFilterButtons) {
    const field = button.dataset.filterField || ''
    const filtered =
      field === 'limit'
        ? state.filters.limit !== '50'
        : field === 'timestamp'
          ? state.rangePreset !== 'all'
          : Boolean(FILTER_FIELDS[field] && getFilterValues(field).length > 0)
    const active = state.openField === field
    button.classList.toggle('is-active', active)
    button.classList.toggle('is-filtered', filtered)
    button.setAttribute('aria-pressed', active || filtered ? 'true' : 'false')
  }
  updateColumnFilterIndicators()
}

function renderHeaderFilterDropdown() {
  if (!headerFilterDropdown || !headerFilterList || !messageWorkspace) return

  const field = state.openField
  const config = FILTER_FIELDS[field]
  if (!config && field !== 'timestamp' && field !== 'limit') {
    headerFilterDropdown.hidden = true
    return
  }

  let optionMarkup = []
  if (field === 'timestamp' || field === 'limit') {
    optionMarkup = buildStaticHeaderOptions(field).map(
      ({ value, label, active }) => `<button class="header-filter-option${
        active ? ' is-active' : ''
      }" type="button" data-filter-value="${escapeHtml(value)}">
        <span class="header-filter-option-label">${escapeHtml(label)}</span>
        <span class="header-filter-option-check">✓</span>
      </button>`
    )
  } else {
    const currentValues = getFilterValues(field)
    const snapshotOptions =
      state.openFieldOptions && Array.isArray(state.openFieldOptions[field])
        ? state.openFieldOptions[field]
        : []
    const options = mergeFieldOptions(field, [], snapshotOptions, currentValues)

    optionMarkup = [
      `<button class="header-filter-option${
        currentValues.length === 0 ? ' is-active' : ''
      }" type="button" data-filter-value="">
        <span class="header-filter-option-label">${escapeHtml(config.allLabel)}</span>
        <span class="header-filter-option-check">✓</span>
      </button>`,
    ]
    for (const value of options) {
      optionMarkup.push(
        `<button class="header-filter-option${
          currentValues.includes(value) ? ' is-active' : ''
        }" type="button" data-filter-value="${escapeHtml(value)}">
          <span class="header-filter-option-label">${escapeHtml(
            formatFilterValue(field, value)
          )}</span>
          <span class="header-filter-option-check">✓</span>
        </button>`
      )
    }
  }

  const activeButton = columnFilterButtons.find(
    (button) => (button.dataset.filterField || '') === field
  )
  if (!activeButton) {
    headerFilterDropdown.hidden = true
    return
  }

  const workspaceRect = messageWorkspace.getBoundingClientRect()
  const buttonRect = activeButton.getBoundingClientRect()

  headerFilterList.innerHTML = optionMarkup.join('')
  headerFilterDropdown.style.top = `${buttonRect.bottom - workspaceRect.top + 6}px`
  headerFilterDropdown.style.left = `${buttonRect.left - workspaceRect.left}px`
  headerFilterDropdown.hidden = false
}

function renderFilterControls({ messageResult, groups, devices }) {
  state.messageResult = messageResult || createEmptyMessageResult()
  state.availableFilterOptions = buildAvailableFilterOptions({
    groups,
    devices,
    messageResult: state.messageResult,
  })
  state.deviceLabelMap = buildDeviceLabelMap({
    devices,
    messageResult: state.messageResult,
  })
  renderHeaderFilterDropdown()
  updateColumnFilterButtons()
}

function clearDashboard() {
  metricOnline.textContent = '0'
  metricGroups.textContent = '0'
  metricEvents.textContent = '0'
  metricForwarded.textContent = '0'
  groupBody.textContent = ''
  groupEmpty.hidden = false
  deviceList.textContent = ''
  deviceEmpty.hidden = false
  deviceCountTag.textContent = '0 台'
  messageBody.textContent = ''
  messageEmpty.hidden = false
  lastUpdated.textContent = '--'
  renderFilterControls({ messageResult: createEmptyMessageResult(), groups: [], devices: [] })
}

function applyRangePreset(preset) {
  state.rangePreset = RANGE_PRESETS[preset] ? preset : 'all'
  updateColumnFilterButtons()
}

function openHeaderFilter(field) {
  if (!FILTER_FIELDS[field] && field !== 'timestamp' && field !== 'limit') return

  if (state.openField === field && headerFilterDropdown && !headerFilterDropdown.hidden) {
    closeHeaderFilter()
    return
  }

  state.openField = field
  state.openFieldOptions = buildFieldOptionsFromFacets(state.availableFilterOptions)
  renderHeaderFilterDropdown()
  updateColumnFilterButtons()
  headerFilterList?.querySelector('.header-filter-option')?.focus()

  if (field === 'timestamp' || field === 'limit') {
    return
  }

  fetchFieldOptions(field)
    .then(() => {
      if (state.openField !== field) return
      renderHeaderFilterDropdown()
      headerFilterList?.querySelector('.header-filter-option')?.focus()
    })
    .catch(() => {})
}

function renderOverview(overview) {
  metricOnline.textContent = String(overview.onlineDevices || 0)
  metricGroups.textContent = String(overview.groups || 0)
  metricEvents.textContent = String(overview.totalEvents || 0)
  metricForwarded.textContent = String(overview.forwardedMessages || 0)
}

function renderGroups(groups) {
  groupBody.textContent = ''

  if (!Array.isArray(groups) || groups.length === 0) {
    groupEmpty.hidden = false
    return
  }

  groupEmpty.hidden = true

  for (const group of groups) {
    const row = document.createElement('tr')
    row.innerHTML = `
      <td>${escapeHtml(group.groupId)}</td>
      <td>${Number(group.onlineDevices || 0)}</td>
      <td>${Number(group.relayEvents || 0)}</td>
      <td>${escapeHtml(formatTime(group.lastEventAt))}</td>
    `
    groupBody.append(row)
  }
}

function renderDevices(devices) {
  deviceList.textContent = ''

  const list = Array.isArray(devices) ? devices : []
  deviceCountTag.textContent = `${list.length} 台`

  if (list.length === 0) {
    deviceEmpty.hidden = false
    return
  }

  deviceEmpty.hidden = true

  for (const device of list) {
    const deviceStatus = formatDeviceStatus(device.status)
    const item = document.createElement('li')
    item.innerHTML = `
      <div class="device-top">
        <strong class="device-name">${escapeHtml(device.deviceName || '未知设备')}</strong>
        <span class="device-meta">${escapeHtml(device.groupId || 'default')}</span>
      </div>
      <div class="device-meta">ID: ${escapeHtml(device.deviceId || '-')}</div>
      <div class="device-meta">最后活动: ${escapeHtml(formatTime(device.lastSeenAt))}</div>
    `
    item
      .querySelector('.device-top')
      ?.insertAdjacentHTML(
        'beforeend',
        `<span class="device-status device-status-${escapeHtml(deviceStatus)}">${escapeHtml(deviceStatus)}</span>`
      )
    item.insertAdjacentHTML(
      'beforeend',
      `<div class="device-meta">Status: ${escapeHtml(deviceStatus)}</div>`
    )
    deviceList.append(item)
  }
}

function renderMessages(result) {
  messageBody.textContent = ''

  const items = result && Array.isArray(result.items) ? result.items : []

  if (items.length === 0) {
    messageEmpty.hidden = false
    return
  }

  messageEmpty.hidden = true

  for (const [index, item] of items.entries()) {
    const row = document.createElement('tr')
    row.innerHTML = `
      <td>${Number(result?.offset || 0) + index + 1}</td>
      <td>${escapeHtml(formatTime(item.timestamp))}</td>
      <td>${escapeHtml(item.type || '-')}</td>
      <td>${escapeHtml(item.groupId || '-')}</td>
      <td>${escapeHtml(item.deviceName || item.deviceId || '-')}</td>
      <td title="${escapeHtml(item.content || '')}">${escapeHtml(item.content || '-')}</td>
      <td>${Number(item.forwardedCount || 0)}</td>
    `
    messageBody.append(row)
  }
}

function resolveOpsLoginUrl() {
  const url = new URL(`${window.location.protocol}//${window.location.hostname}:8000/`)
  url.searchParams.set('redirect', window.location.href)
  return url.toString()
}

function gotoUnifiedLogin() {
  clearLoginRedirect()
  state.redirecting = true
  window.location.replace(resolveOpsLoginUrl())
}

function scheduleLoginRedirect(delayMs = 1200) {
  if (state.redirecting) return
  clearLoginRedirect()
  state.loginTimer = window.setTimeout(() => {
    state.loginTimer = null
    gotoUnifiedLogin()
  }, delayMs)
}

function showCheckingView() {
  setView(VIEW.boot)
}

function showAuthView(message) {
  clearDashboard()
  setAuthMessage(message)
  setView(VIEW.auth)
}

function showDashboardView() {
  clearLoginRedirect()
  setView(VIEW.dashboard)
}

function enterUnauthenticatedFlow(message, delayMs = 1200) {
  state.user = null
  stopAutoRefresh()
  showAuthView(message)
  scheduleLoginRedirect(delayMs)
}

async function refreshDashboard() {
  if (!state.user || state.loading) return
  state.loading = true

  try {
    const query = buildMessageQuery()
    const [overviewRes, groupsRes, devicesRes, messagesRes] = await Promise.all([
      api('/api/relay/overview'),
      api('/api/relay/groups'),
      api('/api/relay/devices'),
      api(`/api/relay/messages${query ? `?${query}` : ''}`),
    ])

    const messageResult = messagesRes.data || createEmptyMessageResult()
    renderOverview(overviewRes.data || {})
    renderGroups(groupsRes.data || [])
    renderDevices(devicesRes.data || [])
    renderFilterControls({
      messageResult,
      groups: groupsRes.data || [],
      devices: devicesRes.data || [],
    })
    renderMessages(messageResult)
    lastUpdated.textContent = formatTime(Date.now())
  } catch (error) {
    if (error.status === 401) {
      enterUnauthenticatedFlow('登录态已过期，正在跳转统一登录...', 800)
      return
    }

    lastUpdated.textContent = `刷新失败: ${error.message}`
  } finally {
    state.loading = false
  }
}

function startAutoRefresh() {
  stopAutoRefresh()
  state.timer = window.setInterval(() => {
    refreshDashboard()
  }, 6000)
}

function stopAutoRefresh() {
  if (!state.timer) return
  window.clearInterval(state.timer)
  state.timer = null
}

async function checkAuth() {
  showCheckingView()

  let lastError = null

  for (let attempt = 0; attempt < 2; attempt += 1) {
    try {
      const me = await api('/api/auth/me')
      state.user = me.data || null
      showDashboardView()
      await refreshDashboard()
      startAutoRefresh()
      return
    } catch (error) {
      lastError = error
      if (error && error.status === 401) break
      if (attempt === 0) {
        await new Promise((resolve) => {
          window.setTimeout(resolve, 260)
        })
      }
    }
  }

  if (lastError) {
    console.warn('[sms-sync] auth check failed:', lastError.message)
  }

  if (lastError && lastError.status === 401) {
    enterUnauthenticatedFlow('未检测到登录态，正在跳转统一登录...')
  } else if (lastError) {
    enterUnauthenticatedFlow(`登录态校验失败：${lastError.message}`, 1600)
  } else {
    enterUnauthenticatedFlow('未检测到登录态，正在跳转统一登录...')
  }
}

headerFilterList?.addEventListener('click', async (event) => {
  const option = event.target.closest('[data-filter-value]')
  if (!option || !state.openField) return

  event.preventDefault()
  const activeField = state.openField

  if (activeField === 'limit') {
    state.filters.limit = String(option.dataset.filterValue || '50')
    closeHeaderFilter()
    await refreshDashboard()
    return
  }

  if (activeField === 'timestamp') {
    applyRangePreset(option.dataset.filterValue || 'all')
    closeHeaderFilter()
    await refreshDashboard()
    return
  }

  if (!FILTER_FIELDS[activeField]) return

  toggleFilterValue(activeField, option.dataset.filterValue || '')
  renderHeaderFilterDropdown()
  updateColumnFilterButtons()
  await refreshDashboard()

  if (state.openField !== activeField) return

  try {
    await fetchFieldOptions(activeField)
  } catch {
    return
  }

  if (state.openField !== activeField) return
  renderHeaderFilterDropdown()
  headerFilterList?.querySelector('.header-filter-option.is-active')?.focus()
})

clearFiltersBtn?.addEventListener('click', async () => {
  await api('/api/relay/messages/clear', { method: 'POST' })
  await refreshDashboard()
})

document.addEventListener('click', (event) => {
  if (!state.openField) return

  const isHeaderButton = event.target.closest('.column-filter-btn')
  const isDropdown = event.target.closest('#headerFilterDropdown')
  if (isHeaderButton || isDropdown) return

  closeHeaderFilter()
})

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return
  closeHeaderFilter()
})

for (const button of columnFilterButtons) {
  button.addEventListener('click', () => {
    openHeaderFilter(button.dataset.filterField || '')
  })
}

gotoLoginBtn.addEventListener('click', () => {
  setAuthMessage('正在跳转统一登录...')
  gotoUnifiedLogin()
})

window.addEventListener('beforeunload', () => {
  stopAutoRefresh()
  clearLoginRedirect()
})

applyRangePreset('all')
renderFilterControls({ messageResult: createEmptyMessageResult(), groups: [], devices: [] })
checkAuth()

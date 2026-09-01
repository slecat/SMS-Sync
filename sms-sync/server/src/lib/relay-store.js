function toSafeString(value, fallback = '') {
  const text = String(value ?? '').trim()
  return text || fallback
}

function normalizeGroup(groupId) {
  return toSafeString(groupId, 'default')
}

function normalizeLimit(limit, defaultValue = 50, max = 500) {
  const parsed = Number(limit)
  if (!Number.isFinite(parsed)) return defaultValue
  const fixed = Math.trunc(parsed)
  if (fixed <= 0) return defaultValue
  return Math.min(fixed, max)
}

function normalizeOffset(offset) {
  const parsed = Number(offset)
  if (!Number.isFinite(parsed)) return 0
  const fixed = Math.trunc(parsed)
  return fixed < 0 ? 0 : fixed
}

function normalizeTimestamp(value) {
  if (value === undefined || value === null || value === '') return null
  const parsed = Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) return null
  return parsed
}

function normalizeExactCount(value) {
  if (value === undefined || value === null || value === '') return null
  const parsed = Number(value)
  if (!Number.isFinite(parsed)) return null
  const fixed = Math.trunc(parsed)
  return fixed < 0 ? null : fixed
}

function normalizeStringFilterSet(value, normalizer = toSafeString) {
  if (value === undefined || value === null || value === '') return null

  const rawItems = Array.isArray(value) ? value : String(value).split(',')
  const values = rawItems
    .map((item) => normalizer(item).toLowerCase())
    .filter(Boolean)

  return values.length > 0 ? new Set(values) : null
}

function normalizeCountFilterSet(value) {
  if (value === undefined || value === null || value === '') return null

  const rawItems = Array.isArray(value) ? value : String(value).split(',')
  const values = rawItems
    .map((item) => normalizeExactCount(item))
    .filter((item) => item !== null)

  return values.length > 0 ? new Set(values) : null
}

function normalizeStatus(value, fallback = 'online') {
  if (value === 'offline') return 'offline'
  if (value === 'online') return 'online'
  return fallback
}

function normalizePlatform(value, fallback = '') {
  const normalized = toSafeString(value, fallback).toLowerCase()
  if (normalized === 'mobile') return 'mobile'
  if (normalized === 'desktop') return 'desktop'
  return fallback ? normalizePlatform(fallback, '') : ''
}

function cloneSockets(client) {
  if (client?.sockets instanceof Set) {
    return new Set(client.sockets)
  }
  if (client?.ws) {
    return new Set([client.ws])
  }
  return new Set()
}

function firstSocket(sockets) {
  for (const socket of sockets) {
    return socket
  }
  return null
}

function resolveClientSocket(existing, incomingSocket, sockets) {
  if (existing?.ws && sockets.has(existing.ws)) {
    return existing.ws
  }
  if (incomingSocket && sockets.has(incomingSocket)) {
    return incomingSocket
  }
  return firstSocket(sockets)
}

function toPublicClient(client) {
  if (!client) return null
  return {
    ...client,
    sockets: cloneSockets(client),
    socketCount: cloneSockets(client).size,
    ws: client.ws || firstSocket(cloneSockets(client)),
  }
}

const fs = require('fs')
const path = require('path')

function createRelayStore({ maxEvents = 3000, persistencePath = '' } = {}) {
  const sizeLimit = normalizeLimit(maxEvents, 3000, 100000)
  const createdAt = Date.now()
  const clients = new Map()
  const events = []
  const relayByType = new Map()
  let sequence = 0

  const persistenceFile = persistencePath
    ? path.resolve(process.cwd(), persistencePath)
    : ''
  if (persistenceFile) {
    try {
      const saved = JSON.parse(fs.readFileSync(persistenceFile, 'utf8'))
      if (Array.isArray(saved)) events.push(...saved.slice(0, sizeLimit))
    } catch (error) {
      if (error.code !== 'ENOENT') console.warn(`[relay-store] load failed: ${error.message}`)
    }
  }

  for (const event of events) {
    if (event.kind === 'relay') {
      const type = toSafeString(event.type, 'unknown')
      relayByType.set(type, (relayByType.get(type) || 0) + 1)
    }
  }

  function persistEvents() {
    if (!persistenceFile) return
    try {
      fs.mkdirSync(path.dirname(persistenceFile), { recursive: true })
      const tempFile = `${persistenceFile}.tmp`
      fs.writeFileSync(tempFile, JSON.stringify(events), 'utf8')
      fs.renameSync(tempFile, persistenceFile)
    } catch (error) {
      console.warn(`[relay-store] persist failed: ${error.message}`)
    }
  }

  function eventToPublic(event) {
    return { ...event }
  }

  function trimEvents() {
    if (events.length <= sizeLimit) return
    events.length = sizeLimit
  }

  function pushEvent(event) {
    events.unshift(event)
    trimEvents()
    persistEvents()
  }

  function addTypeCounter(type) {
    const key = toSafeString(type, 'unknown')
    relayByType.set(key, (relayByType.get(key) || 0) + 1)
  }

  function upsertClient(
    deviceId,
    {
      ws = null,
      groupId = 'default',
      deviceName = 'Unknown device',
      lastSeenAt = Date.now(),
      status = 'online',
      platform = '',
    } = {}
  ) {
    const id = toSafeString(deviceId)
    if (!id) return null

    const existing = clients.get(id)
    const sockets = cloneSockets(existing)
    const hadRecord = Boolean(existing)
    if (ws) {
      sockets.add(ws)
    }

    const record = {
      ws: resolveClientSocket(existing, ws, sockets),
      sockets,
      deviceId: id,
      groupId: normalizeGroup(groupId),
      deviceName: toSafeString(deviceName, existing?.deviceName || 'Unknown device'),
      connectedAt: existing ? existing.connectedAt : Date.now(),
      lastSeenAt: normalizeTimestamp(lastSeenAt) || Date.now(),
      status: normalizeStatus(status, existing ? existing.status : 'online'),
      platform: normalizePlatform(platform, existing?.platform || ''),
    }

    clients.set(id, record)
    return {
      client: toPublicClient(record),
      becameOnline: !hadRecord,
    }
  }

  function removeClient(deviceId, ws = null) {
    const id = toSafeString(deviceId)
    if (!id || !clients.has(id)) return false

    const existing = clients.get(id)
    const sockets = cloneSockets(existing)

    if (ws) {
      sockets.delete(ws)
    } else {
      sockets.clear()
    }

    if (sockets.size > 0) {
      clients.set(id, {
        ...existing,
        sockets,
        ws: resolveClientSocket(existing, null, sockets),
        lastSeenAt: Date.now(),
      })
      return false
    }

    return clients.delete(id)
  }

  function getClient(deviceId) {
    const id = toSafeString(deviceId)
    if (!id) return null
    return toPublicClient(clients.get(id))
  }

  function touchClient(deviceId, patch = {}) {
    const id = toSafeString(deviceId)
    if (!id) return null
    if (!clients.has(id)) return null

    const existing = clients.get(id)
    const next = {
      ...existing,
      sockets: cloneSockets(existing),
      lastSeenAt: Date.now(),
    }

    if (patch.deviceName) {
      next.deviceName = toSafeString(
        patch.deviceName,
        existing.deviceName || 'Unknown device'
      )
    }

    if (patch.groupId) {
      next.groupId = normalizeGroup(patch.groupId)
    }

    if (patch.status) {
      next.status = normalizeStatus(patch.status, existing.status || 'online')
    }

    if (patch.platform) {
      next.platform = normalizePlatform(patch.platform, existing.platform || '')
    }

    next.ws = resolveClientSocket(existing, null, next.sockets)
    clients.set(id, next)
    return toPublicClient(next)
  }

  function listOnlineDevices({ groupId } = {}) {
    const groupFilter = groupId ? normalizeGroup(groupId) : null
    const result = []

    clients.forEach((client) => {
      if (groupFilter && client.groupId !== groupFilter) return
      result.push({
        deviceId: client.deviceId,
        deviceName: client.deviceName,
        groupId: client.groupId,
        connectedAt: client.connectedAt,
        lastSeenAt: client.lastSeenAt,
        status: client.status || 'online',
        platform: client.platform || '',
      })
    })

    result.sort((a, b) => b.lastSeenAt - a.lastSeenAt)
    return result
  }

  function toEvent(payload, kind = 'relay') {
    sequence += 1
    const now = Date.now()
    const timestamp = normalizeTimestamp(payload.timestamp) || now

    return {
      id: `${timestamp}-${sequence}`,
      kind,
      type: toSafeString(payload.type, 'unknown'),
      messageId: toSafeString(payload.messageId, ''),
      groupId: normalizeGroup(payload.groupId),
      deviceId: toSafeString(payload.deviceId, ''),
      deviceName: toSafeString(payload.deviceName, ''),
      phone: toSafeString(payload.phone, ''),
      content: toSafeString(payload.content, ''),
      forwardedTo: Array.isArray(payload.forwardedTo)
        ? payload.forwardedTo.map((item) => String(item)).filter(Boolean)
        : [],
      forwardedCount: Array.isArray(payload.forwardedTo)
        ? payload.forwardedTo.length
        : 0,
      timestamp,
      createdAt: now,
      metadata:
        payload.metadata && typeof payload.metadata === 'object'
          ? payload.metadata
          : {},
    }
  }

  function recordRelayEvent(payload) {
    const event = toEvent(payload, 'relay')
    pushEvent(event)
    addTypeCounter(event.type)
    return eventToPublic(event)
  }

  function recordSystemEvent(payload) {
    const event = toEvent(payload, 'system')
    pushEvent(event)
    return eventToPublic(event)
  }

  function clearMessages() {
    events.length = 0
    relayByType.clear()
    persistEvents()
  }

  function queryMessages({
    limit,
    offset,
    type,
    groupId,
    deviceId,
    phone,
    forwardedCount,
    keyword,
    since,
    until,
    kinds,
  } = {}) {
    const safeLimit = normalizeLimit(limit, 50, 500)
    const safeOffset = normalizeOffset(offset)
    const typeFilterSet = normalizeStringFilterSet(type)
    const groupFilterSet = normalizeStringFilterSet(groupId, normalizeGroup)
    const deviceFilterSet = normalizeStringFilterSet(deviceId)
    const phoneFilterSet = normalizeStringFilterSet(phone)
    const forwardedCountFilterSet = normalizeCountFilterSet(forwardedCount)
    const keywordFilter = keyword ? toSafeString(keyword).toLowerCase() : ''
    const sinceTs = normalizeTimestamp(since)
    const untilTs = normalizeTimestamp(until)

    const kindFilterSet = Array.isArray(kinds)
      ? new Set(kinds.map((item) => String(item).toLowerCase()))
      : null

    const filtered = events.filter((event) => {
      if (kindFilterSet && !kindFilterSet.has(String(event.kind).toLowerCase())) {
        return false
      }
      if (typeFilterSet && !typeFilterSet.has(String(event.type).toLowerCase())) return false
      if (groupFilterSet && !groupFilterSet.has(String(event.groupId).toLowerCase())) return false
      if (deviceFilterSet && !deviceFilterSet.has(String(event.deviceId).toLowerCase())) {
        return false
      }
      if (phoneFilterSet && !phoneFilterSet.has(String(event.phone).toLowerCase())) return false
      if (
        forwardedCountFilterSet &&
        !forwardedCountFilterSet.has(Number(event.forwardedCount || 0))
      ) {
        return false
      }
      if (sinceTs && event.timestamp < sinceTs) return false
      if (untilTs && event.timestamp > untilTs) return false

      if (keywordFilter) {
        const haystack = [
          event.type,
          event.groupId,
          event.deviceId,
          event.deviceName,
          event.phone,
          event.content,
        ]
          .join(' ')
          .toLowerCase()

        if (!haystack.includes(keywordFilter)) return false
      }

      return true
    })

    const facets = {
      types: [],
      groupIds: [],
      deviceIds: [],
      phones: [],
      forwardedCounts: [],
    }
    const typeSet = new Set()
    const groupSet = new Set()
    const deviceSet = new Set()
    const phoneSet = new Set()
    const forwardedCountSet = new Set()

    for (const event of filtered) {
      if (event.type && !typeSet.has(event.type)) {
        typeSet.add(event.type)
        facets.types.push(event.type)
      }
      if (event.groupId && !groupSet.has(event.groupId)) {
        groupSet.add(event.groupId)
        facets.groupIds.push(event.groupId)
      }
      if (event.deviceId && !deviceSet.has(event.deviceId)) {
        deviceSet.add(event.deviceId)
        facets.deviceIds.push(event.deviceId)
      }
      if (event.phone && !phoneSet.has(event.phone)) {
        phoneSet.add(event.phone)
        facets.phones.push(event.phone)
      }
      const count = Number(event.forwardedCount || 0)
      if (!forwardedCountSet.has(count)) {
        forwardedCountSet.add(count)
        facets.forwardedCounts.push(count)
      }
    }

    return {
      total: filtered.length,
      limit: safeLimit,
      offset: safeOffset,
      facets,
      items: filtered.slice(safeOffset, safeOffset + safeLimit).map(eventToPublic),
    }
  }

  function getGroupStats() {
    const map = new Map()

    clients.forEach((client) => {
      const key = normalizeGroup(client.groupId)
      if (!map.has(key)) {
        map.set(key, {
          groupId: key,
          onlineDevices: 0,
          relayEvents: 0,
          systemEvents: 0,
          forwardedMessages: 0,
          lastEventAt: null,
        })
      }

      const row = map.get(key)
      row.onlineDevices += 1
    })

    events.forEach((event) => {
      const key = normalizeGroup(event.groupId)
      if (!map.has(key)) {
        map.set(key, {
          groupId: key,
          onlineDevices: 0,
          relayEvents: 0,
          systemEvents: 0,
          forwardedMessages: 0,
          lastEventAt: null,
        })
      }

      const row = map.get(key)
      if (event.kind === 'system') {
        row.systemEvents += 1
      } else {
        row.relayEvents += 1
        row.forwardedMessages += Number(event.forwardedCount) || 0
      }

      row.lastEventAt = row.lastEventAt
        ? Math.max(row.lastEventAt, event.timestamp)
        : event.timestamp
    })

    return [...map.values()].sort((a, b) => {
      if (b.onlineDevices !== a.onlineDevices) return b.onlineDevices - a.onlineDevices
      if (b.relayEvents !== a.relayEvents) return b.relayEvents - a.relayEvents
      return a.groupId.localeCompare(b.groupId)
    })
  }

  function getOverview() {
    const byType = {}
    relayByType.forEach((count, type) => {
      byType[type] = count
    })

    const groups = getGroupStats()
    const totalForwarded = events.reduce(
      (sum, item) => sum + (item.forwardedCount || 0),
      0
    )

    return {
      startedAt: createdAt,
      uptimeSeconds: Math.max(0, Math.floor((Date.now() - createdAt) / 1000)),
      onlineDevices: clients.size,
      groups: groups.length,
      totalEvents: events.length,
      relayByType: byType,
      forwardedMessages: totalForwarded,
      lastEventAt: events[0] ? events[0].timestamp : null,
    }
  }

  return {
    upsertClient,
    removeClient,
    getClient,
    touchClient,
    listOnlineDevices,
    recordRelayEvent,
    recordSystemEvent,
    clearMessages,
    queryMessages,
    getGroupStats,
    getOverview,
  }
}

module.exports = {
  createRelayStore,
}

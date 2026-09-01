const WebSocket = require('ws')
const { normalizeAck, normalizeRegister, normalizeSms } = require('./protocol/v2')

function normalizeDeviceName(deviceName) {
  const normalizedName = String(deviceName || '').trim()
  return normalizedName || 'Unknown device'
}

function normalizeGroupId(groupId) {
  const normalizedGroupId = String(groupId || 'default').trim()
  return normalizedGroupId || 'default'
}

function normalizeStatus(status, fallback = 'online') {
  if (status === 'offline') return 'offline'
  if (status === 'online') return 'online'
  return fallback
}

function normalizePlatform(platform, fallback = '') {
  const normalized = String(platform || '').trim().toLowerCase()
  if (normalized === 'mobile') return 'mobile'
  if (normalized === 'desktop') return 'desktop'
  return fallback || ''
}

function isAllowedDeviceId(deviceId) {
  const normalized = String(deviceId || '').trim()
  if (!normalized) return false
  return normalized !== 'unknown_device'
}

function buildPresencePayload({
  deviceId,
  deviceName,
  groupId,
  status = 'online',
  timestamp = Date.now(),
  platform = '',
}) {
  return {
    type: 'device-presence',
    deviceId,
    deviceName: normalizeDeviceName(deviceName),
    groupId: normalizeGroupId(groupId),
    status,
    timestamp,
    ...(platform ? { platform: normalizePlatform(platform) } : {}),
  }
}

function canSend(socket) {
  return socket && socket.readyState === WebSocket.OPEN
}

function broadcastPresence(store, senderDeviceId, groupId, payload, recipients) {
  const peers = store.listOnlineDevices({ groupId })
  for (const peer of peers) {
    if (peer.deviceId === senderDeviceId) continue
    const target = store.getClient(peer.deviceId)
    if (!target || !canSend(target.ws)) continue
    target.ws.send(JSON.stringify(payload))
    if (recipients) {
      recipients.push(peer.deviceId)
    }
  }
}

function attachWsRelay(server, store) {
  const wss = new WebSocket.Server({ server })
  const pendingByMessageId = new Map()

  wss.on('connection', (ws) => {
    let deviceId = null
    let groupId = null
    let deviceName = null

    ws.on('message', (message) => {
      try {
        const data = JSON.parse(message)

        if (data.type === 'register') {
          let registrationPayload
          try {
            registrationPayload = normalizeRegister({
              ...data,
              protocolVersion: data.protocolVersion || 2,
              platform: data.platform || 'desktop',
            })
          } catch (_error) {
            return
          }
          const incomingId = registrationPayload.deviceId
          if (!isAllowedDeviceId(incomingId)) return

          deviceId = incomingId
          groupId = normalizeGroupId(registrationPayload.groupId)
          deviceName = normalizeDeviceName(registrationPayload.deviceName)
          const platform = normalizePlatform(registrationPayload.platform)
          const now = Date.now()

          const registration = store.upsertClient(deviceId, {
            ws,
            groupId,
            deviceName,
            platform,
            lastSeenAt: now,
            status: 'online',
          })

          if (registration?.becameOnline) {
            store.recordSystemEvent({
              type: 'register',
              deviceId,
              deviceName,
              groupId,
              content: 'device online',
              timestamp: now,
            })
          }

          const peers = store.listOnlineDevices({ groupId })
          for (const peer of peers) {
            if (peer.deviceId === deviceId) continue
            if (!canSend(ws)) continue
            ws.send(
              JSON.stringify(
                buildPresencePayload({
                  deviceId: peer.deviceId,
                  deviceName: peer.deviceName,
                  groupId,
                  status: peer.status || 'online',
                  timestamp: peer.lastSeenAt || now,
                  platform: peer.platform || '',
                })
              )
            )
          }

          // Replay persisted SMS envelopes on every reconnect. Desktop/mobile
          // clients deduplicate by messageId, so reconnects are safe.
          if (canSend(ws)) {
            for (const replay of store.getReplay({ groupId, limit: 100 })) {
              if (replay.sourceDeviceId === deviceId) continue
              ws.send(JSON.stringify(replay))
            }
          }

          if (registration?.becameOnline) {
            broadcastPresence(
              store,
              deviceId,
              groupId,
              buildPresencePayload({
                deviceId,
                deviceName,
                groupId,
                status: 'online',
                timestamp: now,
                platform,
              })
            )
          }
          return
        }

        if (data.type === 'server-ack' || data.type === 'delivery-ack') {
          let ack
          try { ack = normalizeAck({ ...data, protocolVersion: data.protocolVersion || 2 }) } catch (_error) { return }
          const source = pendingByMessageId.get(ack.messageId)
          if (source && canSend(source)) {
            source.send(JSON.stringify({ ...ack, type: 'delivery-ack', protocolVersion: 2, persistedAt: Date.now() }))
          }
          if (data.type === 'delivery-ack') pendingByMessageId.delete(ack.messageId)
          return
        }

        if (data.type === 'sms' || data.type === 'test' || data.type === 'device-presence') {
          if (!groupId) {
            groupId = normalizeGroupId(data.groupId)
          }

          const senderGroup = groupId
          const recipients = []

          if (data.type === 'device-presence') {
            const status = normalizeStatus(data.status, null)
            const now = Date.now()

            if (!status) {
              return
            }

            if (data.deviceName) {
              deviceName = normalizeDeviceName(data.deviceName)
            }
            const platform = normalizePlatform(
              data.platform,
              store.getClient(deviceId || String(data.deviceId || '').trim())?.platform || ''
            )

            const outbound = buildPresencePayload({
              deviceId: deviceId || String(data.deviceId || '').trim(),
              deviceName: deviceName || data.deviceName,
              groupId: senderGroup,
              status,
              timestamp: now,
              platform,
            })

            if (deviceId) {
              if (status === 'offline') {
                store.removeClient(deviceId)
              } else {
                store.touchClient(deviceId, {
                  groupId: senderGroup,
                  deviceName,
                  status,
                  platform,
                })
              }
            }

            broadcastPresence(store, deviceId, senderGroup, outbound, recipients)

            store.recordSystemEvent({
              type: 'device-presence',
              groupId: senderGroup,
              deviceId: outbound.deviceId,
              deviceName: outbound.deviceName,
              content: status === 'offline' ? 'device offline' : 'device online',
              forwardedTo: recipients,
              timestamp: outbound.timestamp,
            })
            return
          }

          if (deviceId) {
            store.touchClient(deviceId, {
              groupId: senderGroup,
              deviceName: data.deviceName,
              status: 'online',
            })
          }

          let outbound = data
          if (data.type === 'sms') {
            try {
              outbound = normalizeSms({
                ...data,
                protocolVersion: data.protocolVersion || 2,
                receivedAt: data.receivedAt || data.timestamp,
                sourceDeviceId: data.sourceDeviceId || deviceId,
              })
            } catch (_error) {
              return
            }
            pendingByMessageId.set(outbound.messageId, ws)
          }
          const peers = store.listOnlineDevices({ groupId: senderGroup })
          for (const peer of peers) {
            if (peer.deviceId === deviceId) continue
            const target = store.getClient(peer.deviceId)
            if (!target || !canSend(target.ws)) continue
            target.ws.send(JSON.stringify(outbound))
            recipients.push(peer.deviceId)
          }

          store.recordRelayEvent({
            type: data.type,
            groupId: senderGroup,
            deviceId: deviceId || String(data.deviceId || ''),
            deviceName: String(data.deviceName || deviceName || ''),
            phone: String(data.phone || ''),
            content: String(data.content || ''),
            forwardedTo: recipients,
            timestamp: Number(data.timestamp || data.receivedAt) || Date.now(),
            messageId: outbound.messageId,
            metadata: {
              source: 'ws',
            },
          })
          if (data.type === 'sms' && canSend(ws)) {
            ws.send(JSON.stringify({
              type: 'server-ack',
              protocolVersion: 2,
              messageId: outbound.messageId,
              persistedAt: Date.now(),
            }))
          }
          return
        }

        store.recordSystemEvent({
          type: 'ignored',
          deviceId: deviceId || String(data.deviceId || ''),
          deviceName: String(data.deviceName || deviceName || ''),
          groupId: groupId || String(data.groupId || 'default'),
          content: `unsupported type: ${String(data.type || 'unknown')}`,
          timestamp: Date.now(),
        })
      } catch (error) {
        store.recordSystemEvent({
          type: 'invalid-json',
          deviceId,
          deviceName,
          groupId: groupId || 'default',
          content: error.message,
          timestamp: Date.now(),
        })
      }
    })

    ws.on('close', () => {
      if (!deviceId) return

      const client = store.getClient(deviceId)
      const now = Date.now()
      const removed = store.removeClient(deviceId, ws)

      if (!removed) {
        return
      }

      const offlinePresence = buildPresencePayload({
        deviceId,
        deviceName: client?.deviceName || deviceName,
        groupId: client?.groupId || groupId,
        status: 'offline',
        timestamp: now,
        platform: client?.platform || '',
      })

      broadcastPresence(
        store,
        deviceId,
        offlinePresence.groupId,
        offlinePresence
      )

      store.recordSystemEvent({
        type: 'disconnect',
        deviceId,
        deviceName: offlinePresence.deviceName,
        groupId: offlinePresence.groupId,
        content: 'device offline',
        timestamp: now,
      })
    })
  })

  return wss
}

module.exports = {
  attachWsRelay,
}

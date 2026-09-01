const RETRY_SCHEDULE_MS = [2000, 5000, 15000, 60000, 300000, 900000]
const MAX_RETRY_DELAY_MS = 1800000

function text(value, field, fallback = '') {
  const normalized = String(value ?? '').trim()
  if (!normalized && field) {
    throw new TypeError(`${field} is required`)
  }
  return normalized || fallback
}

function protocolVersion(value) {
  const version = Number(value ?? 2)
  if (version !== 2) {
    throw new TypeError('protocolVersion must be 2')
  }
  return 2
}

function normalizeRegister(input) {
  if (!input || input.type !== 'register') {
    throw new TypeError('register payload is required')
  }

  const capabilities = [...new Set(
    (Array.isArray(input.capabilities) ? input.capabilities : [])
      .map((item) => String(item).trim().toLowerCase())
      .filter(Boolean),
  )].sort()

  const platform = text(input.platform, 'platform').toLowerCase()
  if (platform !== 'mobile' && platform !== 'desktop') {
    throw new TypeError('platform must be mobile or desktop')
  }

  return {
    type: 'register',
    protocolVersion: protocolVersion(input.protocolVersion),
    deviceId: text(input.deviceId, 'deviceId'),
    groupId: text(input.groupId, 'groupId', 'default'),
    deviceName: text(input.deviceName, 'deviceName', 'Unknown device'),
    platform,
    capabilities,
  }
}

function normalizeSms(input) {
  if (!input || input.type !== 'sms') {
    throw new TypeError('sms payload is required')
  }

  const receivedAt = Number(input.receivedAt)
  if (!Number.isSafeInteger(receivedAt) || receivedAt <= 0) {
    throw new TypeError('receivedAt must be a positive integer')
  }

  return {
    type: 'sms',
    protocolVersion: protocolVersion(input.protocolVersion),
    messageId: text(input.messageId, 'messageId'),
    groupId: text(input.groupId, 'groupId', 'default'),
    sourceDeviceId: text(input.sourceDeviceId, 'sourceDeviceId'),
    from: text(input.from, 'from'),
    body: text(input.body, 'body'),
    receivedAt,
    ...(input.signature ? { signature: String(input.signature) } : {}),
  }
}

function normalizeAck(input) {
  if (!input || (input.type !== 'server-ack' && input.type !== 'delivery-ack')) {
    throw new TypeError('ack payload is required')
  }
  return {
    type: input.type,
    protocolVersion: protocolVersion(input.protocolVersion),
    messageId: text(input.messageId, 'messageId'),
    ...(input.deliveryId ? { deliveryId: text(input.deliveryId, 'deliveryId') } : {}),
    persistedAt: Number(input.persistedAt) || Date.now(),
  }
}

function isMatchingAck(ack, expected) {
  return Boolean(
    ack && expected &&
      String(ack.messageId || '') === String(expected.messageId || '') &&
      (!expected.deliveryId || String(ack.deliveryId || '') === String(expected.deliveryId)),
  )
}

function retryDelayMs(attemptCount) {
  const attempt = Math.max(1, Math.trunc(Number(attemptCount) || 1))
  return RETRY_SCHEDULE_MS[attempt - 1] || MAX_RETRY_DELAY_MS
}

module.exports = {
  MAX_RETRY_DELAY_MS,
  RETRY_SCHEDULE_MS,
  isMatchingAck,
  normalizeAck,
  normalizeRegister,
  normalizeSms,
  retryDelayMs,
}

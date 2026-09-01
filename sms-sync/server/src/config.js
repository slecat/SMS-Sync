function readPositiveInt(value, fallback) {
  const num = Number(value)
  if (!Number.isInteger(num) || num <= 0) return fallback
  return num
}

module.exports = {
  port: readPositiveInt(process.env.PORT, 8004),
  opsConsoleBaseUrl: process.env.OPS_CONSOLE_BASE_URL || 'http://127.0.0.1:8000',
  relayMaxEvents: readPositiveInt(process.env.RELAY_MAX_EVENTS, 3000),
}

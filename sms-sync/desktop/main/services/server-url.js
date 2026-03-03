const PROTOCOL_PREFIX_PATTERN = /^[a-zA-Z][a-zA-Z\d+\-.]*:\/\//;
const ALLOWED_PROTOCOLS = new Set(['ws:', 'wss:', 'http:', 'https:']);

function normalizeServerUrl(serverUrl) {
  const raw = String(serverUrl || '').trim();
  if (!raw) {
    return '';
  }

  const candidate = PROTOCOL_PREFIX_PATTERN.test(raw) ? raw : `ws://${raw}`;

  let parsed;
  try {
    parsed = new URL(candidate);
  } catch (_) {
    return '';
  }

  if (!ALLOWED_PROTOCOLS.has(parsed.protocol)) {
    return '';
  }

  return parsed.toString();
}

module.exports = {
  normalizeServerUrl,
};

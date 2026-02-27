const crypto = require('crypto');

const SIGNATURE_KEY = '_sig';
const SIGNATURE_VERSION_KEY = '_sig_v';
const SIGNATURE_VERSION = 1;

function canonicalizeValue(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalizeValue);
  }

  if (value && typeof value === 'object') {
    const canonical = {};
    for (const key of Object.keys(value).sort()) {
      canonical[key] = canonicalizeValue(value[key]);
    }
    return canonical;
  }

  return value;
}

function canonicalJson(value) {
  return JSON.stringify(canonicalizeValue(value));
}

function computeSignature(payload, secret) {
  return crypto
    .createHmac('sha256', Buffer.from(secret, 'utf8'))
    .update(payload, 'utf8')
    .digest('hex');
}

function signPayload(payload, secret) {
  const normalizedSecret = String(secret || '').trim();
  if (!normalizedSecret) {
    return { ...payload };
  }

  const normalizedPayload = canonicalJson(payload);
  const signature = computeSignature(normalizedPayload, normalizedSecret);

  return {
    ...payload,
    [SIGNATURE_VERSION_KEY]: SIGNATURE_VERSION,
    [SIGNATURE_KEY]: signature,
  };
}

function verifyPayload(payload, secret) {
  const normalizedSecret = String(secret || '').trim();
  if (!normalizedSecret) {
    return false;
  }

  const signature = payload?.[SIGNATURE_KEY];
  const version = payload?.[SIGNATURE_VERSION_KEY];
  if (typeof signature !== 'string' || !signature || version !== SIGNATURE_VERSION) {
    return false;
  }

  const unsignedPayload = { ...payload };
  delete unsignedPayload[SIGNATURE_KEY];
  delete unsignedPayload[SIGNATURE_VERSION_KEY];

  const expected = computeSignature(canonicalJson(unsignedPayload), normalizedSecret);
  if (signature.length !== expected.length) {
    return false;
  }

  const actualBuffer = Buffer.from(signature, 'utf8');
  const expectedBuffer = Buffer.from(expected, 'utf8');
  return crypto.timingSafeEqual(actualBuffer, expectedBuffer);
}

module.exports = {
  SIGNATURE_KEY,
  SIGNATURE_VERSION_KEY,
  SIGNATURE_VERSION,
  signPayload,
  verifyPayload,
};

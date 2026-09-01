const test = require('node:test')
const assert = require('node:assert/strict')

const { verifySession } = require('../src/lib/auth-client')

test('verifySession forwards authorization and service key headers', async () => {
  const originalFetch = global.fetch
  let capturedHeaders = null

  global.fetch = async (_url, init = {}) => {
    capturedHeaders = init.headers || {}
    return {
      ok: true,
      status: 200,
      headers: {
        get(name) {
          if (String(name).toLowerCase() === 'content-type') {
            return 'application/json'
          }
          return ''
        },
        getSetCookie() {
          return []
        },
      },
      async json() {
        return { success: true, data: { username: 'svc' } }
      },
      async text() {
        return ''
      },
    }
  }

  try {
    const result = await verifySession({
      baseUrl: 'http://127.0.0.1:8000',
      cookie: '',
      userAgent: 'sms-test',
      authorization: 'Bearer opsk_123.abc',
      serviceKey: 'opsk_direct_key',
    })

    assert.equal(result.ok, true)
    assert.equal(capturedHeaders.authorization, 'Bearer opsk_123.abc')
    assert.equal(capturedHeaders['x-ops-service-key'], 'opsk_direct_key')
  } finally {
    global.fetch = originalFetch
  }
})

function buildOpsAuthUrl(baseUrl, pathname) {
  return new URL(pathname, baseUrl).toString()
}

function buildProxyHeaders({
  cookie = '',
  contentType = '',
  userAgent = '',
  authorization = '',
  serviceKey = '',
} = {}) {
  const headers = {}
  if (cookie) headers.cookie = cookie
  if (contentType) headers['content-type'] = contentType
  if (userAgent) headers['user-agent'] = userAgent
  if (authorization) headers.authorization = authorization
  if (serviceKey) headers['x-ops-service-key'] = serviceKey
  return headers
}

async function proxyAuthRequest({
  baseUrl,
  pathname,
  method,
  cookie,
  body,
  contentType,
  userAgent,
  authorization,
  serviceKey,
}) {
  const url = buildOpsAuthUrl(baseUrl, pathname)
  const headers = buildProxyHeaders({ cookie, contentType, userAgent, authorization, serviceKey })
  const hasBody = method !== 'GET' && method !== 'HEAD' && body !== undefined

  const response = await fetch(url, {
    method,
    headers,
    body: hasBody ? body : undefined,
  })

  const setCookies = typeof response.headers.getSetCookie === 'function'
    ? response.headers.getSetCookie()
    : []

  const contentTypeHeader = response.headers.get('content-type') || ''
  const isJson = contentTypeHeader.includes('application/json')

  let bodyJson = null
  let bodyText = ''

  if (isJson) {
    bodyJson = await response.json().catch(() => ({ success: false, error: '响应解析失败' }))
  } else {
    bodyText = await response.text()
  }

  return {
    ok: response.ok,
    status: response.status,
    setCookies,
    contentType: contentTypeHeader,
    isJson,
    bodyJson,
    bodyText,
  }
}

async function verifySession({ baseUrl, cookie, userAgent, authorization, serviceKey }) {
  const response = await proxyAuthRequest({
    baseUrl,
    pathname: '/api/auth/me',
    method: 'GET',
    cookie,
    userAgent,
    authorization,
    serviceKey,
  })

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      error: response.bodyJson && response.bodyJson.error ? response.bodyJson.error : '未登录',
    }
  }

  return {
    ok: true,
    status: response.status,
    data: response.bodyJson && response.bodyJson.data ? response.bodyJson.data : null,
  }
}

module.exports = {
  buildProxyHeaders,
  proxyAuthRequest,
  verifySession,
}

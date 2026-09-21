const { verifySession } = require('../lib/auth-client')
const { sendError } = require('../lib/http')

function createRequireSession({ opsConsoleBaseUrl }) {
  return async function requireSession(req, res, next) {
    const cookie = req.headers.cookie || ''
    const authorization = req.headers.authorization || ''
    const serviceKey = req.headers['x-ops-service-key'] || ''
    if (!cookie && !authorization && !serviceKey) {
      sendError(res, 401, '未登录')
      return
    }

    try {
      const result = await verifySession({
        baseUrl: opsConsoleBaseUrl,
        cookie,
        userAgent: req.headers['user-agent'] || '',
        authorization,
        serviceKey,
      })

      if (!result.ok) {
        sendError(res, 401, result.error || '登录已过期')
        return
      }

      req.user = result.data
      next()
    } catch (error) {
      sendError(res, 502, '认证服务不可用', error.message)
    }
  }
}

module.exports = {
  createRequireSession,
}

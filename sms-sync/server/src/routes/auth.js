const express = require('express')
const { proxyAuthRequest } = require('../lib/auth-client')
const { asyncHandler } = require('../lib/http')

function createAuthRouter({ opsConsoleBaseUrl }) {
  const router = express.Router()

  function proxyAuth(pathname) {
    return asyncHandler(async (req, res) => {
      const contentType = req.headers['content-type'] || 'application/json'
      const body = req.method === 'GET' || req.method === 'HEAD'
        ? undefined
        : JSON.stringify(req.body || {})

      const proxied = await proxyAuthRequest({
        baseUrl: opsConsoleBaseUrl,
        pathname,
        method: req.method,
        cookie: req.headers.cookie || '',
        authorization: req.headers.authorization || '',
        serviceKey: req.headers['x-ops-service-key'] || '',
        body,
        contentType,
        userAgent: req.headers['user-agent'] || '',
      })

      if (proxied.setCookies && proxied.setCookies.length > 0) {
        res.setHeader('set-cookie', proxied.setCookies)
      }

      res.status(proxied.status)
      if (proxied.isJson) {
        res.json(proxied.bodyJson)
        return
      }

      if (proxied.contentType) {
        res.setHeader('content-type', proxied.contentType)
      }
      res.send(proxied.bodyText)
    })
  }

  router.post('/login', proxyAuth('/api/auth/login'))
  router.get('/me', proxyAuth('/api/auth/me'))
  router.post('/logout', proxyAuth('/api/auth/logout'))

  return router
}

module.exports = {
  createAuthRouter,
}

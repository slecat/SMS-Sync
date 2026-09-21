const path = require('path')
const express = require('express')
const cors = require('cors')
const { createAuthRouter } = require('./routes/auth')
const { createRelayRouter } = require('./routes/relay')
const { createRequireSession } = require('./middleware/require-session')
const { sendError } = require('./lib/http')

function createApp({ config, store }) {
  const app = express()

  app.use(cors())
  app.use(express.json())
  app.use(
    express.static(path.join(__dirname, '..', 'public'), {
      setHeaders: (res, filePath) => {
        if (filePath.endsWith('.html') || filePath.endsWith('.js') || filePath.endsWith('.css')) {
          res.setHeader('Cache-Control', 'no-store')
        }
      },
    })
  )

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      service: 'ops-sms-sync-service',
      onlineDevices: store.listOnlineDevices().length,
      timestamp: Date.now(),
    })
  })

  app.use('/api/auth', createAuthRouter({ opsConsoleBaseUrl: config.opsConsoleBaseUrl }))

  const requireSession = createRequireSession({ opsConsoleBaseUrl: config.opsConsoleBaseUrl })
  app.use('/api/relay', requireSession, createRelayRouter({ store }))

  app.use((req, res, next) => {
    if (req.path.startsWith('/api/')) {
      sendError(res, 404, '接口不存在')
      return
    }
    next()
  })

  app.use((error, _req, res, _next) => {
    const status = error && Number.isInteger(error.status) ? error.status : 500
    const message = error && error.message ? error.message : '服务器内部错误'
    sendError(res, status, message)
  })

  return app
}

module.exports = {
  createApp,
}

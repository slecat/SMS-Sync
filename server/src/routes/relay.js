const express = require('express')

function splitKinds(value) {
  if (!value) return null
  return String(value)
    .split(',')
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean)
}

function createRelayRouter({ store }) {
  const router = express.Router()

  router.get('/overview', (req, res) => {
    res.json({ success: true, data: store.getOverview() })
  })

  router.get('/devices', (req, res) => {
    const groupId = req.query.groupId ? String(req.query.groupId) : undefined
    res.json({
      success: true,
      data: store.listOnlineDevices({ groupId }),
    })
  })

  router.get('/groups', (_req, res) => {
    res.json({ success: true, data: store.getGroupStats() })
  })

  router.get('/messages', (req, res) => {
    const result = store.queryMessages({
      limit: req.query.limit,
      offset: req.query.offset,
      type: req.query.type,
      groupId: req.query.groupId,
      deviceId: req.query.deviceId,
      phone: req.query.phone,
      forwardedCount: req.query.forwardedCount,
      keyword: req.query.keyword,
      since: req.query.since,
      until: req.query.until,
      kinds: splitKinds(req.query.kinds),
    })

    res.json({ success: true, data: result })
  })

  router.post('/messages/clear', (_req, res) => {
    store.clearMessages()
    res.json({ success: true, data: { cleared: true } })
  })

  return router
}

module.exports = {
  createRelayRouter,
}

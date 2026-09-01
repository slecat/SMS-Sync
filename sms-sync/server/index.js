require('dotenv').config()
const http = require('http')
const config = require('./src/config')
const { createApp } = require('./src/app')
const { createRelayStore } = require('./src/lib/relay-store')
const { attachWsRelay } = require('./src/ws-relay')

const store = createRelayStore({
  maxEvents: config.relayMaxEvents,
  persistencePath: config.relayPersistencePath,
})
const app = createApp({ config, store })
const server = http.createServer(app)

attachWsRelay(server, store)

server.listen(config.port, '0.0.0.0', () => {
  console.log(`Server running on port ${config.port}`)
})

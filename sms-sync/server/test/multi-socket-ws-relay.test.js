const test = require('node:test')
const assert = require('node:assert/strict')
const http = require('http')
const WebSocket = require('ws')

const { createRelayStore } = require('./../src/lib/relay-store')
const { attachWsRelay } = require('./../src/ws-relay')

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function waitFor(predicate, { timeoutMs = 2000, intervalMs = 20 } = {}) {
  const startedAt = Date.now()

  return new Promise((resolve, reject) => {
    const tick = () => {
      try {
        const result = predicate()
        if (result) {
          resolve(result)
          return
        }
      } catch (error) {
        reject(error)
        return
      }

      if (Date.now() - startedAt >= timeoutMs) {
        reject(new Error('Timed out waiting for condition'))
        return
      }

      setTimeout(tick, intervalMs)
    }

    tick()
  })
}

async function createFixture() {
  const store = createRelayStore({ maxEvents: 50 })
  const server = http.createServer()
  const wss = attachWsRelay(server, store)

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  const { port } = server.address()
  const sockets = []

  async function connect({ deviceId, deviceName, groupId }) {
    const socket = new WebSocket(`ws://127.0.0.1:${port}`)
    sockets.push(socket)

    const messages = []
    socket.on('message', (data) => {
      messages.push(JSON.parse(data.toString()))
    })

    await new Promise((resolve, reject) => {
      socket.once('open', resolve)
      socket.once('error', reject)
    })

    socket.send(
      JSON.stringify({
        type: 'register',
        deviceId,
        deviceName,
        groupId,
      })
    )

    return { socket, messages }
  }

  async function close() {
    await Promise.all(
      sockets.map(
        (socket) =>
          new Promise((resolve) => {
            if (
              socket.readyState === WebSocket.CLOSED ||
              socket.readyState === WebSocket.CLOSING
            ) {
              resolve()
              return
            }
            socket.once('close', resolve)
            socket.close()
          })
      )
    )

    await new Promise((resolve) => wss.close(resolve))
    await new Promise((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve()))
    )
  }

  return { store, connect, close }
}

test('closing a secondary socket should not mark the device offline', async () => {
  const fixture = await createFixture()

  try {
    const alpha = await fixture.connect({
      deviceId: 'alpha',
      deviceName: 'Alpha',
      groupId: 'group-a',
    })

    await fixture.connect({
      deviceId: 'beta',
      deviceName: 'Beta',
      groupId: 'group-a',
    })

    await waitFor(() =>
      alpha.messages.find(
        (message) =>
          message.type === 'device-presence' &&
          message.deviceId === 'beta' &&
          message.status === 'online'
      )
    )

    const betaSecondary = await fixture.connect({
      deviceId: 'beta',
      deviceName: 'Beta',
      groupId: 'group-a',
    })

    betaSecondary.socket.close()
    await new Promise((resolve) => betaSecondary.socket.once('close', resolve))
    await delay(200)

    assert.equal(
      alpha.messages.some(
        (message) =>
          message.type === 'device-presence' &&
          message.deviceId === 'beta' &&
          message.status === 'offline'
      ),
      false
    )

    assert.deepEqual(
      fixture.store.listOnlineDevices({ groupId: 'group-a' }).map((device) => device.deviceId),
      ['beta', 'alpha']
    )
  } finally {
    await fixture.close()
  }
})

const test = require('node:test')
const assert = require('node:assert/strict')
const http = require('http')
const WebSocket = require('ws')

const { createRelayStore } = require('../src/lib/relay-store')
const { attachWsRelay } = require('../src/ws-relay')

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

  async function connect({
    deviceId,
    deviceName,
    groupId,
    connectionId,
    platform,
  }) {
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
        connectionId,
        platform,
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

test('ws relay should ignore placeholder device ids during register', async () => {
  const fixture = await createFixture()

  try {
    const alpha = await fixture.connect({
      deviceId: '11111111-1111-4111-8111-111111111111',
      deviceName: 'Alpha',
      groupId: 'group-a',
      connectionId: 'c-alpha',
      platform: 'desktop',
    })

    await fixture.connect({
      deviceId: 'unknown_device',
      deviceName: 'Ghost',
      groupId: 'group-a',
      connectionId: 'c-ghost',
      platform: 'mobile',
    })

    await delay(200)

    assert.equal(
      alpha.messages.some(
        (message) =>
          message.type === 'device-presence' &&
          message.deviceId === 'unknown_device'
      ),
      false
    )

    assert.deepEqual(
      fixture.store.listOnlineDevices({ groupId: 'group-a' }).map((device) => device.deviceId),
      ['11111111-1111-4111-8111-111111111111']
    )
  } finally {
    await fixture.close()
  }
})

test('ws relay should keep platform on server-generated presence while ignoring connectionId for identity', async () => {
  const fixture = await createFixture()

  try {
    const alpha = await fixture.connect({
      deviceId: '11111111-1111-4111-8111-111111111111',
      deviceName: 'Alpha',
      groupId: 'group-a',
      connectionId: 'c-alpha',
      platform: 'desktop',
    })

    await fixture.connect({
      deviceId: '22222222-2222-4222-8222-222222222222',
      deviceName: 'Beta',
      groupId: 'group-a',
      connectionId: 'c-beta-1',
      platform: 'mobile',
    })

    const onlinePresence = await waitFor(() =>
      alpha.messages.find(
        (message) =>
          message.type === 'device-presence' &&
          message.deviceId === '22222222-2222-4222-8222-222222222222' &&
          message.status === 'online'
      )
    )

    assert.equal(onlinePresence.platform, 'mobile')

    const betaSecondary = await fixture.connect({
      deviceId: '22222222-2222-4222-8222-222222222222',
      deviceName: 'Beta',
      groupId: 'group-a',
      connectionId: 'c-beta-2',
      platform: 'mobile',
    })

    betaSecondary.socket.close()
    await new Promise((resolve) => betaSecondary.socket.once('close', resolve))
    await delay(200)

    assert.equal(
      alpha.messages.filter(
        (message) =>
          message.type === 'device-presence' &&
          message.deviceId === '22222222-2222-4222-8222-222222222222' &&
          message.status === 'online'
      ).length,
      1
    )
  } finally {
    await fixture.close()
  }
})

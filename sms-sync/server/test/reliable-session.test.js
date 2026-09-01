const test = require('node:test')
const assert = require('node:assert/strict')
const http = require('http')
const WebSocket = require('ws')

const { createRelayStore } = require('../src/lib/relay-store')
const { attachWsRelay } = require('../src/ws-relay')

function waitFor(predicate, timeoutMs = 3000) {
  const startedAt = Date.now()
  return new Promise((resolve, reject) => {
    const tick = () => {
      const result = predicate()
      if (result) return resolve(result)
      if (Date.now() - startedAt >= timeoutMs) {
        return reject(new Error('Timed out waiting for reliable session'))
      }
      setTimeout(tick, 20)
    }
    tick()
  })
}

async function createFixture() {
  const store = createRelayStore({ maxEvents: 200 })
  const server = http.createServer()
  const wss = attachWsRelay(server, store)
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  const port = server.address().port

  async function connect(deviceId, platform) {
    const socket = new WebSocket(`ws://127.0.0.1:${port}`)
    const messages = []
    socket.on('message', (data) => messages.push(JSON.parse(data.toString())))
    await new Promise((resolve, reject) => {
      socket.once('open', resolve)
      socket.once('error', reject)
    })
    socket.send(JSON.stringify({
      type: 'register',
      protocolVersion: 2,
      deviceId,
      platform,
      deviceName: deviceId,
      groupId: 'reliable-test',
    }))
    return { socket, messages }
  }

  async function close() {
    await new Promise((resolve) => wss.close(resolve))
    await new Promise((resolve) => server.close(resolve))
  }

  return { connect, close }
}

test('desktop reconnect replays offline SMS and ACKs each message once', async () => {
  const fixture = await createFixture()
  let phone
  let desktop
  try {
    phone = await fixture.connect('phone-1', 'mobile')
    desktop = await fixture.connect('desktop-1', 'desktop')

    const messageIds = ['m-1', 'm-2', 'm-3']
    for (const messageId of messageIds) {
      phone.socket.send(JSON.stringify({
        type: 'sms',
        protocolVersion: 2,
        messageId,
        groupId: 'reliable-test',
        sourceDeviceId: 'phone-1',
        from: '95588',
        body: `验证码 ${messageId}`,
        receivedAt: Date.now(),
        timestamp: Date.now(),
      }))
    }

    await waitFor(() => messageIds.every((id) =>
      desktop.messages.some((message) => message.type === 'sms' && message.messageId === id)
    ))

    for (const messageId of messageIds) {
      desktop.socket.send(JSON.stringify({
        type: 'delivery-ack',
        protocolVersion: 2,
        messageId,
      }))
    }
    await waitFor(() => messageIds.every((id) =>
      phone.messages.some((message) => message.type === 'delivery-ack' && message.messageId === id)
    ))

    await new Promise((resolve) => {
      desktop.socket.once('close', resolve)
      desktop.socket.close()
    })
    desktop = await fixture.connect('desktop-1', 'desktop')
    await waitFor(() => messageIds.every((id) =>
      desktop.messages.some((message) => message.type === 'sms' && message.messageId === id)
    ))

    assert.equal(
      new Set(desktop.messages.filter((message) => message.type === 'sms').map((message) => message.messageId)).size,
      messageIds.length,
    )
  } finally {
    for (const client of [phone, desktop]) {
      if (client?.socket && client.socket.readyState < WebSocket.CLOSING) client.socket.close()
    }
    await fixture.close()
  }
})

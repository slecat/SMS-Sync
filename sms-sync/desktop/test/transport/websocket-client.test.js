const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { WebSocketClient } = require('../../main/transport/websocket-client');

class FakeSocket extends EventEmitter {
  constructor(url) {
    super();
    this.url = url;
    this.readyState = FakeWebSocket.OPEN;
    this.sent = [];
    this.closed = false;
  }

  send(payload) {
    this.sent.push(payload);
  }

  close() {
    this.closed = true;
    this.emit('close');
  }
}

class FakeWebSocket {
  static OPEN = 1;
  static instances = [];

  constructor(url) {
    const socket = new FakeSocket(url);
    FakeWebSocket.instances.push(socket);
    return socket;
  }
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function createClient(overrides = {}) {
  const statuses = [];
  const messages = [];
  const errors = [];
  const parseErrors = [];
  let disconnectedCount = 0;

  const client = new WebSocketClient({
    WebSocketImpl: FakeWebSocket,
    onStatusChange: (status, message) => statuses.push({ status, message }),
    onMessage: (message) => messages.push(message),
    onDisconnected: () => {
      disconnectedCount += 1;
    },
    onError: (error) => errors.push(error),
    onParseError: (error) => parseErrors.push(error),
    getRegisterPayload: () => ({ type: 'register', deviceId: 'desktop' }),
    getHeartbeatPayload: () => ({ type: 'device-presence', deviceId: 'desktop' }),
    heartbeatInterval: 10,
    ...overrides,
  });

  return {
    client,
    statuses,
    messages,
    errors,
    parseErrors,
    getDisconnectedCount: () => disconnectedCount,
  };
}

test('WebSocketClient should mark disconnected when server url is empty', () => {
  const { client, statuses, getDisconnectedCount } = createClient();
  client.connect('');

  assert.deepEqual(statuses, [{ status: 'disconnected', message: '未配置服务器地址' }]);
  assert.equal(getDisconnectedCount(), 1);
});

test('WebSocketClient should handle connect, message and invalid payload', () => {
  FakeWebSocket.instances = [];
  const { client, statuses, messages, parseErrors } = createClient();
  client.connect('ws://localhost:3000');

  const socket = FakeWebSocket.instances[0];
  assert.ok(socket, 'socket should be created');

  socket.emit('open');
  assert.equal(JSON.parse(socket.sent[0]).type, 'register');

  socket.emit('message', Buffer.from(JSON.stringify({ type: 'sms', from: '10086' })));
  assert.equal(messages.length, 1);
  assert.equal(messages[0].type, 'sms');

  socket.emit('message', Buffer.from('not-json'));
  assert.equal(parseErrors.length, 1);

  socket.emit('close');
  assert.equal(statuses[0].status, 'connecting');
  assert.equal(statuses[1].status, 'connected');
  assert.equal(statuses[2].status, 'disconnected');
});

test('WebSocketClient should send heartbeats and stop after disconnect', async () => {
  FakeWebSocket.instances = [];
  const { client } = createClient();
  client.connect('ws://localhost:3000');

  const socket = FakeWebSocket.instances[0];
  socket.emit('open');

  await wait(35);
  const payloadTypes = socket.sent.map((raw) => JSON.parse(raw).type);
  assert.ok(payloadTypes.includes('register'));
  assert.ok(payloadTypes.includes('device-presence'));

  const sentBeforeDisconnect = socket.sent.length;
  client.disconnect();
  await wait(20);
  assert.equal(socket.sent.length, sentBeforeDisconnect);
});

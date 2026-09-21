const WebSocket = require('ws');
const url = 'ws://111.228.32.128:8004';
const groupId = 'Dulin';
const deviceId = 'desktop_smoke_msg_' + Date.now();
const ws = new WebSocket(url);
let done = false;
const finish = (code, msg) => { if (!done) { done = true; if (msg) console.log(msg); process.exit(code); } };
ws.on('open', () => {
  ws.send(JSON.stringify({ type: 'register', deviceId, deviceName: 'DesktopSmokeMsg', groupId }));
  console.log('LISTENER_REGISTERED ' + deviceId);
});
ws.on('message', (m) => {
  const text = m.toString();
  console.log('LISTENER_MESSAGE ' + text);
  try {
    const data = JSON.parse(text);
    if (data.type === 'test' || data.type === 'sms') {
      finish(0, 'LISTENER_SUCCESS_MESSAGE_TYPE_' + data.type);
    }
  } catch {}
});
ws.on('error', (e) => finish(3, 'LISTENER_ERROR ' + e.message));
setTimeout(() => finish(2, 'LISTENER_TIMEOUT'), 60000);

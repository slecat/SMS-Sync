require('dotenv').config();
const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const clients = new Map();

function buildPresencePayload(deviceId, deviceName, groupId, timestamp = Date.now()) {
  return {
    type: 'device-presence',
    deviceId,
    deviceName: deviceName || '未知设备',
    groupId: groupId || 'default',
    timestamp,
  };
}

wss.on('connection', (ws) => {
  let deviceId = null;
  let groupId = null;
  let deviceName = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      if (data.type === 'register') {
        const incomingId = String(data.deviceId || '').trim();
        if (!incomingId) {
          return;
        }
        deviceId = incomingId;
        groupId = String(data.groupId || 'default').trim() || 'default';
        deviceName = String(data.deviceName || '').trim() || '未知设备';
        clients.set(deviceId, {
          ws,
          groupId,
          deviceName,
          lastSeenAt: Date.now(),
        });
        console.log(`Device registered: ${deviceId}, group: ${groupId}`);

        // Send current online peers in the same group to the newly registered client.
        clients.forEach((client, clientId) => {
          if (clientId === deviceId || client.groupId !== groupId) {
            return;
          }
          if (ws.readyState !== WebSocket.OPEN) {
            return;
          }
          ws.send(
            JSON.stringify(
              buildPresencePayload(
                clientId,
                client.deviceName,
                groupId,
                client.lastSeenAt || Date.now()
              )
            )
          );
        });

        // Also notify peers that this device is now online.
        const selfPresence = buildPresencePayload(
          deviceId,
          deviceName,
          groupId,
          Date.now()
        );
        clients.forEach((client, clientId) => {
          if (
            clientId !== deviceId &&
            client.groupId === groupId &&
            client.ws.readyState === WebSocket.OPEN
          ) {
            client.ws.send(JSON.stringify(selfPresence));
          }
        });
      } else if (data.type === 'sms') {
        const senderGroup = groupId;
        clients.forEach((client, clientId) => {
          if (clientId !== deviceId && client.groupId === senderGroup && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify(data));
          }
        });
      } else if (data.type === 'test') {
        const senderGroup = groupId;
        clients.forEach((client, clientId) => {
          if (clientId !== deviceId && client.groupId === senderGroup && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify(data));
          }
        });
      } else if (data.type === 'device-presence') {
        const senderGroup = groupId;
        if (deviceId && clients.has(deviceId)) {
          const existing = clients.get(deviceId);
          existing.lastSeenAt = Date.now();
          const incomingName = String(data.deviceName || '').trim();
          if (incomingName) {
            existing.deviceName = incomingName;
            deviceName = incomingName;
          }
          clients.set(deviceId, existing);
        }
        clients.forEach((client, clientId) => {
          if (clientId !== deviceId && client.groupId === senderGroup && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify({
              ...data,
              timestamp: Date.now(),
            }));
          }
        });
      }
    } catch (error) {
      console.error('Error handling message:', error);
    }
  });

  ws.on('close', () => {
    if (deviceId) {
      clients.delete(deviceId);
      console.log(`Device disconnected: ${deviceId}`);
    }
  });
});

const PORT = process.env.PORT || 8004;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

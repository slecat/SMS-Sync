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

wss.on('connection', (ws) => {
  let deviceId = null;
  let groupId = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      if (data.type === 'register') {
        deviceId = data.deviceId;
        groupId = data.groupId || 'default';
        clients.set(deviceId, { ws, groupId });
        console.log(`Device registered: ${deviceId}, group: ${groupId}`);
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
        clients.forEach((client, clientId) => {
          if (clientId !== deviceId && client.groupId === senderGroup && client.ws.readyState === WebSocket.OPEN) {
            client.ws.send(JSON.stringify({
              ...data,
              timestamp: data.timestamp || Date.now(),
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

const dgram = require('dgram');

class UdpService {
  constructor({
    listenPort = 8888,
    broadcastPorts = [8888, 8889],
    broadcastHost = '255.255.255.255',
    broadcastInterval = 5000,
    onMessage,
    onError,
  }) {
    this.listenPort = listenPort;
    this.broadcastPorts = broadcastPorts;
    this.broadcastHost = broadcastHost;
    this.broadcastInterval = broadcastInterval;
    this.onMessage = onMessage;
    this.onError = onError;
    this.server = null;
    this.broadcastSocket = null;
    this.broadcastTimer = null;
    this.getPresencePayload = null;
  }

  start({ getPresencePayload }) {
    this.stop();
    this.getPresencePayload = getPresencePayload;

    this.server = dgram.createSocket('udp4');
    this.server.on('message', (msg) => {
      try {
        const data = JSON.parse(msg.toString());
        this.onMessage(data, 'udp');
      } catch (error) {
        this.onError(error);
      }
    });

    this.server.bind(this.listenPort, () => {
      this.startBroadcastLoop();
    });
  }

  stop() {
    if (this.broadcastTimer) {
      clearInterval(this.broadcastTimer);
      this.broadcastTimer = null;
    }

    if (this.broadcastSocket) {
      this.broadcastSocket.close();
      this.broadcastSocket = null;
    }

    if (this.server) {
      this.server.close();
      this.server = null;
    }
  }

  sendOneShot(payload, port = this.listenPort) {
    const socket = dgram.createSocket('udp4');
    socket.bind(() => {
      socket.setBroadcast(true);
      socket.send(JSON.stringify(payload), port, this.broadcastHost, () => {
        socket.close();
      });
    });
  }

  startBroadcastLoop() {
    this.broadcastSocket = dgram.createSocket('udp4');
    this.broadcastSocket.bind(() => {
      this.broadcastSocket.setBroadcast(true);
    });

    this.broadcastTimer = setInterval(() => {
      const payload = this.getPresencePayload();
      const encodedPayload = JSON.stringify(payload);

      for (const port of this.broadcastPorts) {
        this.broadcastSocket.send(encodedPayload, port, this.broadcastHost, (error) => {
          if (error) {
            this.onError(error);
          }
        });
      }
    }, this.broadcastInterval);
  }
}

module.exports = {
  UdpService,
};

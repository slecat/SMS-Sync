class WebSocketClient {
  constructor({
    WebSocketImpl,
    onStatusChange,
    onMessage,
    onDisconnected,
    onError,
    onParseError,
    getRegisterPayload,
    getHeartbeatPayload,
    heartbeatInterval = 5000,
  }) {
    this.WebSocketImpl = WebSocketImpl;
    this.onStatusChange = onStatusChange;
    this.onMessage = onMessage;
    this.onDisconnected = onDisconnected;
    this.onError = onError;
    this.onParseError = onParseError;
    this.getRegisterPayload = getRegisterPayload;
    this.getHeartbeatPayload = getHeartbeatPayload;
    this.heartbeatInterval = heartbeatInterval;
    this.socket = null;
    this.heartbeatTimer = null;
    this.connectionEpoch = 0;
    this.lastStatusKey = null;
  }

  connect(serverUrl) {
    this.disconnect();
    const connectionEpoch = this.connectionEpoch;

    if (!serverUrl) {
      this.emitStatus('disconnected', '未配置服务器地址');
      this.onDisconnected();
      return;
    }

    this.emitStatus('connecting', '正在连接...');

    try {
      const socket = new this.WebSocketImpl(serverUrl);
      this.socket = socket;

      socket.on('open', () => {
        if (!this.isActiveConnection(socket, connectionEpoch)) {
          return;
        }

        try {
          socket.send(JSON.stringify(this.getRegisterPayload()));
          // Emit immediate presence so peers can discover this device right
          // after reconnect without waiting for the next heartbeat tick.
          socket.send(JSON.stringify(this.getHeartbeatPayload()));
        } catch (error) {
          this.forceDisconnect(socket, connectionEpoch, '无法连接到服务器');
          this.onError(error);
          return;
        }

        this.emitStatus('connected', '已连接到服务器');
        this.startHeartbeat();
      });

      socket.on('close', () => {
        if (!this.isActiveConnection(socket, connectionEpoch)) {
          return;
        }
        this.socket = null;
        this.stopHeartbeat();
        this.emitStatus('disconnected', '服务器连接已断开');
        this.onDisconnected();
      });

      socket.on('error', (error) => {
        if (!this.isActiveConnection(socket, connectionEpoch)) {
          return;
        }
        this.forceDisconnect(socket, connectionEpoch, '无法连接到服务器');
        this.onError(error);
      });

      socket.on('message', (data) => {
        if (!this.isActiveConnection(socket, connectionEpoch)) {
          return;
        }

        let parsed;
        try {
          parsed = JSON.parse(data.toString());
        } catch (error) {
          this.onParseError(error);
          return;
        }

        this.onMessage(parsed);
      });
    } catch (error) {
      this.emitStatus('disconnected', '无法连接到服务器');
      this.onError(error);
    }
  }

  disconnect() {
    this.connectionEpoch += 1;
    this.stopHeartbeat();
    if (this.socket) {
      this.socket.removeAllListeners();
      this.socket.close();
      this.socket = null;
    }
  }

  send(payload) {
    if (!this.socket || this.socket.readyState !== this.WebSocketImpl.OPEN) {
      return false;
    }

    try {
      this.socket.send(JSON.stringify(payload));
      return true;
    } catch (error) {
      this.onError(error);
      return false;
    }
  }

  startHeartbeat() {
    this.stopHeartbeat();
    this.heartbeatTimer = setInterval(() => {
      this.send(this.getHeartbeatPayload());
    }, this.heartbeatInterval);
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  isActiveConnection(socket, connectionEpoch) {
    return this.socket === socket && this.connectionEpoch === connectionEpoch;
  }

  emitStatus(status, message) {
    const key = `${status}|${message}`;
    if (this.lastStatusKey === key) {
      return;
    }
    this.lastStatusKey = key;
    this.onStatusChange(status, message);
  }

  forceDisconnect(socket, connectionEpoch, message) {
    if (!this.isActiveConnection(socket, connectionEpoch)) {
      return;
    }

    this.stopHeartbeat();
    this.socket = null;

    socket.removeAllListeners();
    try {
      socket.close();
    } catch (_) {}

    this.emitStatus('disconnected', message);
    this.onDisconnected();
  }
}

module.exports = {
  WebSocketClient,
};

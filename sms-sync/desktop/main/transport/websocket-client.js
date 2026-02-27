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
  }

  connect(serverUrl) {
    this.disconnect();

    if (!serverUrl) {
      this.onStatusChange('disconnected', '未配置服务器地址');
      this.onDisconnected();
      return;
    }

    this.onStatusChange('connecting', '正在连接...');

    try {
      const socket = new this.WebSocketImpl(serverUrl);
      this.socket = socket;

      socket.on('open', () => {
        if (this.socket !== socket) {
          return;
        }

        try {
          socket.send(JSON.stringify(this.getRegisterPayload()));
        } catch (error) {
          this.onError(error);
          return;
        }

        this.onStatusChange('connected', '已连接到服务器');
        this.startHeartbeat();
      });

      socket.on('close', () => {
        if (this.socket !== socket) {
          return;
        }
        this.socket = null;
        this.stopHeartbeat();
        this.onStatusChange('disconnected', '服务器连接已断开');
        this.onDisconnected();
      });

      socket.on('error', (error) => {
        if (this.socket !== socket) {
          return;
        }
        this.onStatusChange('disconnected', '无法连接到服务器');
        this.onError(error);
      });

      socket.on('message', (data) => {
        if (this.socket !== socket) {
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
      this.onStatusChange('disconnected', '无法连接到服务器');
      this.onError(error);
    }
  }

  disconnect() {
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
}

module.exports = {
  WebSocketClient,
};

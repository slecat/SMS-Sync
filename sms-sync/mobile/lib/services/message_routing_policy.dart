enum ServerDeliveryMode { disabled, existingChannel, directConnection }

class MessageRoutingPolicy {
  const MessageRoutingPolicy();

  ServerDeliveryMode resolveServerDeliveryMode({
    required String serverUrl,
    required bool hasLiveChannel,
    required bool requireServerAck,
  }) {
    if (serverUrl.isEmpty) {
      return ServerDeliveryMode.disabled;
    }
    if (hasLiveChannel) {
      return ServerDeliveryMode.existingChannel;
    }
    return ServerDeliveryMode.directConnection;
  }

  bool shouldSendToServerWithLiveChannel({
    required String serverUrl,
    required bool hasLiveChannel,
  }) {
    return resolveServerDeliveryMode(
          serverUrl: serverUrl,
          hasLiveChannel: hasLiveChannel,
          requireServerAck: false,
        ) ==
        ServerDeliveryMode.existingChannel;
  }

  bool shouldSendToServerWithDirectConnection({required String serverUrl}) {
    return resolveServerDeliveryMode(
          serverUrl: serverUrl,
          hasLiveChannel: false,
          requireServerAck: false,
        ) ==
        ServerDeliveryMode.directConnection;
  }

  @Deprecated('Use shouldSendToServerWithDirectConnection')
  bool shouldSendToServerWithTemporaryConnection({required String serverUrl}) {
    return shouldSendToServerWithDirectConnection(serverUrl: serverUrl);
  }
}

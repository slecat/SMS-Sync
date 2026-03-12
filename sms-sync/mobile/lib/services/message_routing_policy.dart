class MessageRoutingPolicy {
  const MessageRoutingPolicy();

  bool shouldSendToServerWithLiveChannel({
    required String serverUrl,
    required bool hasLiveChannel,
  }) {
    return serverUrl.isNotEmpty && hasLiveChannel;
  }

  bool shouldSendToServerWithDirectConnection({required String serverUrl}) {
    return serverUrl.isNotEmpty;
  }

  @Deprecated('Use shouldSendToServerWithDirectConnection')
  bool shouldSendToServerWithTemporaryConnection({required String serverUrl}) {
    return shouldSendToServerWithDirectConnection(serverUrl: serverUrl);
  }
}

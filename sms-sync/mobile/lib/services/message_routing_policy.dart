class MessageRoutingPolicy {
  const MessageRoutingPolicy();

  bool shouldSendToServerWithLiveChannel({
    required String serverUrl,
    required bool hasLiveChannel,
  }) {
    return serverUrl.isNotEmpty && hasLiveChannel;
  }

  bool shouldSendToServerWithTemporaryConnection({required String serverUrl}) {
    return serverUrl.isNotEmpty;
  }
}

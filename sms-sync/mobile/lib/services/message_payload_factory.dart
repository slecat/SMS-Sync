class MessagePayloadFactory {
  const MessagePayloadFactory();

  Map<String, dynamic> register({
    required String deviceId,
    required String groupId,
    String? deviceName,
  }) {
    return {
      'type': 'register',
      'protocolVersion': 2,
      'deviceId': deviceId,
      'platform': 'mobile',
      if (deviceName != null) 'deviceName': deviceName,
      'groupId': groupId,
    };
  }

  Map<String, dynamic> devicePresence({
    required String deviceId,
    required String deviceName,
    required String groupId,
    String status = 'online',
    int? timestamp,
  }) {
    return {
      'type': 'device-presence',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'groupId': groupId,
      'status': status,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> sms({
    required String messageId,
    required String from,
    required String body,
    required String groupId,
    int? timestamp,
  }) {
    return {
      'type': 'sms',
      'protocolVersion': 2,
      'messageId': messageId,
      'from': from,
      'body': body,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'receivedAt': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'groupId': groupId,
    };
  }

  Map<String, dynamic> test({
    required String messageId,
    required String from,
    required String body,
    required String groupId,
    int? timestamp,
  }) {
    return {
      'type': 'test',
      'messageId': messageId,
      'from': from,
      'body': body,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'groupId': groupId,
    };
  }
}

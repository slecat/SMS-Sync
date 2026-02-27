class MessagePayloadFactory {
  const MessagePayloadFactory();

  Map<String, dynamic> register({
    required String deviceId,
    required String groupId,
    String? deviceName,
  }) {
    return {
      'type': 'register',
      'deviceId': deviceId,
      if (deviceName != null) 'deviceName': deviceName,
      'groupId': groupId,
    };
  }

  Map<String, dynamic> devicePresence({
    required String deviceId,
    required String deviceName,
    required String groupId,
    int? timestamp,
  }) {
    return {
      'type': 'device-presence',
      'deviceId': deviceId,
      'deviceName': deviceName,
      'groupId': groupId,
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
      'messageId': messageId,
      'from': from,
      'body': body,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
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

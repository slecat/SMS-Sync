import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/message_payload_factory.dart';

void main() {
  group('MessagePayloadFactory', () {
    const factory = MessagePayloadFactory();

    test(
      'register payload should include optional deviceName when provided',
      () {
        final payload = factory.register(
          deviceId: 'device-1',
          groupId: 'group-a',
          deviceName: 'Phone A',
        );

        expect(payload['type'], 'register');
        expect(payload['deviceId'], 'device-1');
        expect(payload['groupId'], 'group-a');
        expect(payload['deviceName'], 'Phone A');
      },
    );

    test('register payload should omit deviceName when null', () {
      final payload = factory.register(
        deviceId: 'device-1',
        groupId: 'group-a',
      );

      expect(payload.containsKey('deviceName'), isFalse);
    });

    test('sms payload should use provided timestamp', () {
      final payload = factory.sms(
        messageId: 'msg-1',
        from: 'sender',
        body: 'hello',
        groupId: 'group-a',
        timestamp: 12345,
      );

      expect(payload['type'], 'sms');
      expect(payload['messageId'], 'msg-1');
      expect(payload['from'], 'sender');
      expect(payload['body'], 'hello');
      expect(payload['groupId'], 'group-a');
      expect(payload['timestamp'], 12345);
    });

    test('devicePresence payload should use provided timestamp', () {
      final payload = factory.devicePresence(
        deviceId: 'device-1',
        deviceName: 'Phone A',
        groupId: 'group-a',
        timestamp: 67890,
      );

      expect(payload['type'], 'device-presence');
      expect(payload['deviceId'], 'device-1');
      expect(payload['deviceName'], 'Phone A');
      expect(payload['groupId'], 'group-a');
      expect(payload['timestamp'], 67890);
    });
  });
}

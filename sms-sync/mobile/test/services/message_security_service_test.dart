import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/message_security_service.dart';

void main() {
  group('MessageSecurityService', () {
    const service = MessageSecurityService();
    const secret = 'sync-secret';
    const payload = <String, dynamic>{
      'type': 'sms',
      'messageId': 'msg-1',
      'from': '10086',
      'body': 'hello',
      'groupId': 'group-a',
      'timestamp': 123456,
    };

    test('sign and verify should succeed with the same secret', () {
      final signed = service.signPayload(payload, secret: secret);

      expect(signed[MessageSecurityService.signatureVersionKey], 1);
      expect(signed[MessageSecurityService.signatureKey], isA<String>());
      expect(service.verifyPayload(signed, secret: secret), isTrue);
    });

    test('verify should fail when payload is tampered', () {
      final signed = service.signPayload(payload, secret: secret);
      final tampered = Map<String, dynamic>.from(signed)..['body'] = 'tampered';

      expect(service.verifyPayload(tampered, secret: secret), isFalse);
    });

    test('verify should fail with wrong secret', () {
      final signed = service.signPayload(payload, secret: secret);

      expect(service.verifyPayload(signed, secret: 'wrong-secret'), isFalse);
    });

    test('empty secret should bypass signature enforcement', () {
      final unsigned = service.signPayload(payload, secret: '');

      expect(unsigned.containsKey(MessageSecurityService.signatureKey), isFalse);
      expect(
        unsigned.containsKey(MessageSecurityService.signatureVersionKey),
        isFalse,
      );
      expect(service.verifyPayload(unsigned, secret: ''), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/message_routing_policy.dart';

void main() {
  group('MessageRoutingPolicy', () {
    const policy = MessageRoutingPolicy();

    test('live channel route should require serverUrl and live channel', () {
      expect(
        policy.shouldSendToServerWithLiveChannel(
          serverUrl: '',
          hasLiveChannel: true,
        ),
        isFalse,
      );
      expect(
        policy.shouldSendToServerWithLiveChannel(
          serverUrl: 'ws://example',
          hasLiveChannel: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldSendToServerWithLiveChannel(
          serverUrl: 'ws://example',
          hasLiveChannel: true,
        ),
        isTrue,
      );
    });

    test('temporary connection route should only require serverUrl', () {
      expect(
        policy.shouldSendToServerWithTemporaryConnection(serverUrl: ''),
        isFalse,
      );
      expect(
        policy.shouldSendToServerWithTemporaryConnection(
          serverUrl: 'ws://example',
        ),
        isTrue,
      );
    });
  });
}

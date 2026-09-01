import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/message_routing_policy.dart';

void main() {
  group('MessageRoutingPolicy', () {
    const policy = MessageRoutingPolicy();

    test('server delivery should prefer live channel when available', () {
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: 'ws://example',
          hasLiveChannel: true,
          requireServerAck: true,
        ),
        ServerDeliveryMode.existingChannel,
      );
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: 'ws://example',
          hasLiveChannel: true,
          requireServerAck: false,
        ),
        ServerDeliveryMode.existingChannel,
      );
    });

    test('server delivery should fall back to direct connection without live channel', () {
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: 'ws://example',
          hasLiveChannel: false,
          requireServerAck: true,
        ),
        ServerDeliveryMode.directConnection,
      );
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: 'ws://example',
          hasLiveChannel: false,
          requireServerAck: false,
        ),
        ServerDeliveryMode.directConnection,
      );
    });

    test('server delivery should disable server sync without serverUrl', () {
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: '',
          hasLiveChannel: true,
          requireServerAck: true,
        ),
        ServerDeliveryMode.disabled,
      );
      expect(
        policy.resolveServerDeliveryMode(
          serverUrl: '',
          hasLiveChannel: false,
          requireServerAck: false,
        ),
        ServerDeliveryMode.disabled,
      );
    });

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

    test('direct connection route should only require serverUrl', () {
      expect(
        policy.shouldSendToServerWithDirectConnection(serverUrl: ''),
        isFalse,
      );
      expect(
        policy.shouldSendToServerWithDirectConnection(
          serverUrl: 'ws://example',
        ),
        isTrue,
      );
    });
  });
}

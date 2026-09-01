import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sms_sync_mobile/platform/native_relay_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test_native_relay_channel');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps native queue counters and timestamps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getRelayHealth');
          return <String, Object?>{
            'pending': 2,
            'sending': 1,
            'retrying': 3,
            'acked': 9,
            'oldestPendingAt': 1000,
            'latestAckAt': 2000,
            'latestErrorCode': 'ack_timeout',
          };
        });

    final health = await NativeRelayChannel(channel: channel).readHealth();

    expect(health.inFlight, 6);
    expect(health.acked, 9);
    expect(health.oldestPendingAt, 1000);
    expect(health.latestErrorCode, 'ack_timeout');
  });
}

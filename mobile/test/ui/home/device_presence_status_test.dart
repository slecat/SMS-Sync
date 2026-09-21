import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/ui/home/device_presence_status.dart';

void main() {
  group('device presence status', () {
    test('explicit online status stays online after timeout', () {
      final online = isDeviceOnline(
        {'status': 'online', 'timestamp': 1000},
        nowMs: 20000,
        timeoutMs: 8000,
      );

      expect(online, isTrue);
    });

    test(
      'explicit offline status stays offline even if timestamp is fresh',
      () {
        final online = isDeviceOnline(
          {'status': 'offline', 'timestamp': 19000},
          nowMs: 20000,
          timeoutMs: 8000,
        );

        expect(online, isFalse);
      },
    );

    test('legacy presence without status still uses timestamp timeout', () {
      final online = isDeviceOnline(
        {'timestamp': 1000},
        nowMs: 20000,
        timeoutMs: 8000,
      );

      expect(online, isFalse);
    });
  });
}

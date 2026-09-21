import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/ui/home/home_view_state.dart';

void main() {
  group('HomeViewState', () {
    test(
      'withoutStaleDevices keeps lifecycle online devices after timeout passes',
      () {
        final state = HomeViewState.initial().withDevicePresence({
          'deviceId': 'mobile-1',
          'deviceName': 'Mounted Phone',
          'source': 'lan',
          'status': 'online',
          'timestamp': 1000,
        }, localDeviceId: 'local-device');

        final cleaned = state.withoutStaleDevices(
          nowMs: 20000,
          timeoutMs: 8000,
        );

        expect(cleaned.onlineDevices.containsKey('mobile-1'), isTrue);
        expect(cleaned.onlineDevices['mobile-1']?['status'], 'online');
      },
    );

    test('explicit offline presence removes device immediately', () {
      final onlineState = HomeViewState.initial().withDevicePresence({
        'deviceId': 'mobile-1',
        'deviceName': 'Mounted Phone',
        'source': 'lan',
        'status': 'online',
        'timestamp': 1000,
      }, localDeviceId: 'local-device');

      final offlineState = onlineState.withDevicePresence({
        'deviceId': 'mobile-1',
        'deviceName': 'Mounted Phone',
        'source': 'lan',
        'status': 'offline',
        'timestamp': 2000,
      }, localDeviceId: 'local-device');

      expect(offlineState.onlineDevices.containsKey('mobile-1'), isFalse);
    });

    test(
      'withReceivedSms counts english code messages as verification codes',
      () {
        final nextState = HomeViewState.initial().withReceivedSms(
          from: 'Service',
          body: 'Your code is 246810.',
        );

        expect(nextState.smsCount, 1);
        expect(nextState.verificationCodeCount, 1);
      },
    );
  });
}

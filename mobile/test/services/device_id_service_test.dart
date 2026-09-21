import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/device_id_service.dart';
import 'package:sms_sync_mobile/services/settings_repository.dart';

class _FakeSettingsRepository extends SettingsRepository {
  String? _deviceId;

  _FakeSettingsRepository({String? deviceId}) : _deviceId = deviceId;

  @override
  Future<String?> getDeviceId() async => _deviceId;

  @override
  Future<void> setDeviceId(String deviceId) async {
    _deviceId = deviceId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sms_sync_app');
  const uuidV4Pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('DeviceIdService', () {
    test('returns stored canonical device id when it is already valid', () async {
      final settings = _FakeSettingsRepository(
        deviceId: 'd58e67b2-bf96-486a-879f-b8f517ee73d7',
      );
      final service = DeviceIdService(platformChannel: channel);

      final deviceId = await service.resolveDeviceId(settings);

      expect(
        deviceId,
        'd58e67b2-bf96-486a-879f-b8f517ee73d7',
      );
    });

    test('generates and persists a uuid when no device id is stored', () async {
      final settings = _FakeSettingsRepository();
      var platformCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getDeviceId') {
              platformCallCount += 1;
              return 'android-platform-id';
            }
            return null;
          });
      final service = DeviceIdService(platformChannel: channel);

      final deviceId = await service.resolveDeviceId(settings);

      expect(deviceId, matches(uuidV4Pattern));
      expect(await settings.getDeviceId(), deviceId);
      expect(platformCallCount, 0);
    });

    test('replaces invalid placeholder ids with a generated uuid', () async {
      final settings = _FakeSettingsRepository(deviceId: 'unknown_device');
      final service = DeviceIdService(platformChannel: channel);

      final deviceId = await service.resolveDeviceId(settings);

      expect(deviceId, matches(uuidV4Pattern));
      expect(deviceId, isNot('unknown_device'));
      expect(await settings.getDeviceId(), deviceId);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sms_sync_mobile/services/device_id_service.dart';
import 'package:sms_sync_mobile/services/message_payload_factory.dart';
import 'package:sms_sync_mobile/services/message_routing_policy.dart';
import 'package:sms_sync_mobile/services/message_security_service.dart';
import 'package:sms_sync_mobile/services/message_transport_service.dart';
import 'package:sms_sync_mobile/services/settings_repository.dart';
import 'package:sms_sync_mobile/ui/home/home_action_coordinator.dart';
import 'package:sms_sync_mobile/ui/home/home_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const smsChannel = MethodChannel('test_sms_channel');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(smsChannel, null);
  });

  test(
    'readLatestSms skips sending non-otp messages when filter is enabled',
    () async {
      final transport = _RecordingMessageTransportService();
      final coordinator = HomeActionCoordinator(
        dependencies: HomeDependencies(
          settingsRepository: _FakeSettingsRepository(
            const SyncSettings(
              groupId: 'default',
              serverUrl: '',
              deviceName: '手机端',
              syncSecret: 'secret',
              forwardVerificationCodeOnly: true,
            ),
          ),
          deviceIdService: DeviceIdService(
            platformChannel: const MethodChannel('unused'),
          ),
          messagePayloadFactory: const MessagePayloadFactory(),
          messageTransportService: transport,
          messageRoutingPolicy: const MessageRoutingPolicy(),
          messageSecurityService: const MessageSecurityService(),
          smsMethodChannel: smsChannel,
          supportsBackgroundService: false,
          createBackgroundService: FlutterBackgroundService.new,
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, (call) async {
            if (call.method == 'readLatestSms') {
              return {'from': '物流助手', 'body': '快递单号 123456 已发出，请注意查收。'};
            }
            return null;
          });

      final result = await coordinator.readLatestSms(deviceId: 'device-1');

      expect(result.status, ReadLatestSmsStatus.filtered);
      expect(transport.broadcastPayloads, isEmpty);
      expect(transport.directPayloads, isEmpty);
    },
  );

  test(
    'readLatestSms still sends otp messages when filter is enabled',
    () async {
      final transport = _RecordingMessageTransportService();
      final coordinator = HomeActionCoordinator(
        dependencies: HomeDependencies(
          settingsRepository: _FakeSettingsRepository(
            const SyncSettings(
              groupId: 'default',
              serverUrl: '',
              deviceName: '手机端',
              syncSecret: 'secret',
              forwardVerificationCodeOnly: true,
            ),
          ),
          deviceIdService: DeviceIdService(
            platformChannel: const MethodChannel('unused'),
          ),
          messagePayloadFactory: const MessagePayloadFactory(),
          messageTransportService: transport,
          messageRoutingPolicy: const MessageRoutingPolicy(),
          messageSecurityService: const MessageSecurityService(),
          smsMethodChannel: smsChannel,
          supportsBackgroundService: false,
          createBackgroundService: FlutterBackgroundService.new,
        ),
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(smsChannel, (call) async {
            if (call.method == 'readLatestSms') {
              return {'from': '应用中心', 'body': '您的验证码是 123456，请勿泄露。'};
            }
            return null;
          });

      final result = await coordinator.readLatestSms(deviceId: 'device-1');

      expect(result.status, ReadLatestSmsStatus.success);
      expect(transport.broadcastPayloads, hasLength(1));
      expect(transport.directPayloads, isEmpty);
    },
  );
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository(this._settings);

  final SyncSettings _settings;

  @override
  Future<SyncSettings> loadSettings() async => _settings;
}

class _RecordingMessageTransportService extends MessageTransportService {
  final List<Map<String, dynamic>> broadcastPayloads = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> directPayloads = <Map<String, dynamic>>[];

  @override
  Future<void> broadcastUdp(
    Map<String, dynamic> payload, {
    String host = '255.255.255.255',
    int port = 8888,
  }) async {
    broadcastPayloads.add(payload);
  }

  @override
  Future<void> sendViaDirectWebSocket({
    required String serverUrl,
    required Map<String, dynamic> registerPayload,
    required Map<String, dynamic> payload,
    Duration settleDelay = const Duration(milliseconds: 500),
  }) async {
    directPayloads.add(payload);
  }
}

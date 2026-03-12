import '../../services/app_logger.dart';
import 'home_dependencies.dart';

enum SendTestStatus { success, localFailed, serverFailed }

class SendTestResult {
  const SendTestResult({required this.status, this.error});

  final SendTestStatus status;
  final Object? error;
}

enum ReadLatestSmsStatus { success, notFound, invalidPayload, failed }

class ReadLatestSmsResult {
  const ReadLatestSmsResult({
    required this.status,
    this.from,
    this.body,
    this.error,
  });

  final ReadLatestSmsStatus status;
  final String? from;
  final String? body;
  final Object? error;
}

class HomeActionCoordinator {
  const HomeActionCoordinator({required this.dependencies});

  final HomeDependencies dependencies;

  Future<void> savePreferences({
    required String groupId,
    required String serverUrl,
    required String deviceName,
    required String syncSecret,
  }) async {
    if (syncSecret.trim().isEmpty) {
      throw ArgumentError('syncSecret must not be empty');
    }

    await dependencies.settingsRepository.saveSettings(
      groupId: groupId,
      serverUrl: serverUrl,
      deviceName: deviceName,
      syncSecret: syncSecret.trim(),
    );

    if (dependencies.supportsBackgroundService) {
      final service = dependencies.createBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('reconnect-server');
    }
  }

  Future<SendTestResult> sendTest({required String deviceId}) async {
    final settings = await dependencies.settingsRepository.loadSettings();
    final groupId = settings.groupId;
    final serverUrl = settings.serverUrl;
    final deviceName = settings.deviceName;
    final syncSecret = settings.syncSecret;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final messageId = '${deviceId}_$timestamp';

    final testData = dependencies.messageSecurityService.signPayload(
      dependencies.messagePayloadFactory.test(
        messageId: messageId,
        from: deviceName,
        body: '这是一条测试消息',
        groupId: groupId,
        timestamp: timestamp,
      ),
      secret: syncSecret,
    );

    try {
      await dependencies.messageTransportService.broadcastUdp(testData);
    } catch (e) {
      return SendTestResult(status: SendTestStatus.localFailed, error: e);
    }

    if (dependencies.messageRoutingPolicy
        .shouldSendToServerWithDirectConnection(serverUrl: serverUrl)) {
      try {
        await dependencies.messageTransportService.sendViaDirectWebSocket(
          serverUrl: serverUrl,
          registerPayload: dependencies.messagePayloadFactory.register(
            deviceId: deviceId,
            groupId: groupId,
          ),
          payload: testData,
        );
      } catch (e) {
        return SendTestResult(status: SendTestStatus.serverFailed, error: e);
      }
    }

    return const SendTestResult(status: SendTestStatus.success);
  }

  Future<ReadLatestSmsResult> readLatestSms({required String deviceId}) async {
    try {
      final result = await dependencies.smsMethodChannel.invokeMethod(
        'readLatestSms',
      );
      if (result == null) {
        return const ReadLatestSmsResult(status: ReadLatestSmsStatus.notFound);
      }

      final sms = result as Map<dynamic, dynamic>;
      final from = sms['from'] as String?;
      final body = sms['body'] as String?;
      if (from == null || body == null) {
        return const ReadLatestSmsResult(
          status: ReadLatestSmsStatus.invalidPayload,
        );
      }

      final settings = await dependencies.settingsRepository.loadSettings();
      final groupId = settings.groupId;
      final serverUrl = settings.serverUrl;
      final syncSecret = settings.syncSecret;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final messageId = '${deviceId}_$timestamp';

      final smsData = dependencies.messageSecurityService.signPayload(
        dependencies.messagePayloadFactory.sms(
          messageId: messageId,
          from: from,
          body: body,
          groupId: groupId,
          timestamp: timestamp,
        ),
        secret: syncSecret,
      );

      try {
        await dependencies.messageTransportService.broadcastUdp(smsData);
      } catch (e) {
        AppLogger.debug('Local broadcast failed: $e');
      }

      if (dependencies.messageRoutingPolicy
          .shouldSendToServerWithDirectConnection(serverUrl: serverUrl)) {
        try {
          await dependencies.messageTransportService.sendViaDirectWebSocket(
            serverUrl: serverUrl,
            registerPayload: dependencies.messagePayloadFactory.register(
              deviceId: deviceId,
              groupId: groupId,
            ),
            payload: smsData,
          );
        } catch (e) {
          AppLogger.debug('Server send failed: $e');
        }
      }

      return ReadLatestSmsResult(
        status: ReadLatestSmsStatus.success,
        from: from,
        body: body,
      );
    } catch (e) {
      return ReadLatestSmsResult(status: ReadLatestSmsStatus.failed, error: e);
    }
  }
}

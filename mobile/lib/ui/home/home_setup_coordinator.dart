import 'package:permission_handler/permission_handler.dart';

import '../../platform/runtime_support.dart';
import 'home_dependencies.dart';

class HomeSetupData {
  const HomeSetupData({
    required this.deviceId,
    required this.groupId,
    required this.serverUrl,
    required this.deviceName,
    required this.syncSecret,
    required this.serverStatus,
  });

  final String deviceId;
  final String groupId;
  final String serverUrl;
  final String deviceName;
  final String syncSecret;
  final String serverStatus;
}

class HomeSetupResult {
  const HomeSetupResult({
    required this.data,
    this.settingsError,
    this.permissionError,
  });

  final HomeSetupData data;
  final Object? settingsError;
  final Object? permissionError;
}

class HomeSetupCoordinator {
  const HomeSetupCoordinator({required this.dependencies});

  final HomeDependencies dependencies;

  Future<HomeSetupResult> initialize() async {
    Object? settingsError;
    Object? permissionError;
    var data = const HomeSetupData(
      deviceId: 'unknown_device',
      groupId: 'default',
      serverUrl: '',
      deviceName: '手机端',
      syncSecret: '',
      serverStatus: 'disconnected',
    );

    try {
      final settings = await dependencies.settingsRepository.loadSettings();
      final deviceId = await dependencies.deviceIdService.resolveDeviceId(
        dependencies.settingsRepository,
      );
      final serverStatus = await dependencies.settingsRepository
          .loadServerConnectionStatus();
      data = HomeSetupData(
        deviceId: deviceId,
        groupId: settings.groupId,
        serverUrl: settings.serverUrl,
        deviceName: settings.deviceName,
        syncSecret: settings.syncSecret,
        serverStatus: serverStatus,
      );
    } catch (e) {
      settingsError = e;
    }

    try {
      await _requestPermissions();
    } catch (e) {
      permissionError = e;
    }

    return HomeSetupResult(
      data: data,
      settingsError: settingsError,
      permissionError: permissionError,
    );
  }

  Future<void> _requestPermissions() async {
    if (!supportsAndroidSmsSyncRuntime) {
      return;
    }

    await [
      Permission.sms,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }
}

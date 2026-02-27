import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import 'settings_repository.dart';

class DeviceIdService {
  const DeviceIdService({required MethodChannel platformChannel})
    : _platformChannel = platformChannel;

  final MethodChannel _platformChannel;

  Future<String> resolveDeviceId(SettingsRepository settingsRepository) async {
    final cachedDeviceId = await settingsRepository.getDeviceId();
    if (cachedDeviceId != null && cachedDeviceId.isNotEmpty) {
      return cachedDeviceId;
    }

    try {
      final platformDeviceId = await _platformChannel.invokeMethod<String>(
        'getDeviceId',
      );
      if (platformDeviceId != null && platformDeviceId.isNotEmpty) {
        await settingsRepository.setDeviceId(platformDeviceId);
        return platformDeviceId;
      }
    } catch (_) {}

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final fallbackDeviceId = androidInfo.id;
      if (fallbackDeviceId.isNotEmpty) {
        await settingsRepository.setDeviceId(fallbackDeviceId);
        return fallbackDeviceId;
      }
    } catch (_) {}

    return 'unknown_device';
  }
}

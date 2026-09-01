import 'dart:math';

import 'package:flutter/services.dart';

import 'settings_repository.dart';

class DeviceIdService {
  const DeviceIdService({required MethodChannel platformChannel});

  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  Future<String> resolveDeviceId(SettingsRepository settingsRepository) async {
    final cachedDeviceId = await settingsRepository.getDeviceId();
    if (_isValidDeviceId(cachedDeviceId)) {
      return cachedDeviceId!;
    }

    final generatedDeviceId = _generateUuidV4();
    await settingsRepository.setDeviceId(generatedDeviceId);
    return generatedDeviceId;
  }

  bool _isValidDeviceId(String? deviceId) {
    if (deviceId == null) {
      return false;
    }

    return _uuidV4Pattern.hasMatch(deviceId.trim());
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final compact = bytes.map(hex).join();

    return [
      compact.substring(0, 8),
      compact.substring(8, 12),
      compact.substring(12, 16),
      compact.substring(16, 20),
      compact.substring(20, 32),
    ].join('-');
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncSettings {
  const SyncSettings({
    required this.groupId,
    required this.serverUrl,
    required this.deviceName,
    required this.syncSecret,
  });

  final String groupId;
  final String serverUrl;
  final String deviceName;
  final String syncSecret;
}

class SettingsRepository {
  static const String deviceIdKey = 'deviceId';
  static const String groupIdKey = 'groupId';
  static const String serverUrlKey = 'serverUrl';
  static const String deviceNameKey = 'deviceName';
  static const String syncSecretKey = 'syncSecret';
  static const String lastDevicePresenceKey = 'lastDevicePresence';
  static const String serverConnectionStatusKey = 'serverConnectionStatus';
  static const String pendingNativeSmsQueueKey = 'pendingNativeSmsQueue';

  Future<SharedPreferences> _prefs({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) {
      await prefs.reload();
    }
    return prefs;
  }

  Future<SyncSettings> loadSettings() async {
    final prefs = await _prefs(reload: true);
    return SyncSettings(
      groupId: prefs.getString(groupIdKey) ?? 'default',
      serverUrl: prefs.getString(serverUrlKey) ?? '',
      deviceName: prefs.getString(deviceNameKey) ?? '手机端',
      syncSecret: prefs.getString(syncSecretKey) ?? '',
    );
  }

  Future<void> saveSettings({
    required String groupId,
    required String serverUrl,
    required String deviceName,
    required String syncSecret,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(groupIdKey, groupId);
    await prefs.setString(serverUrlKey, serverUrl);
    await prefs.setString(
      deviceNameKey,
      deviceName.isEmpty ? '手机端' : deviceName,
    );
    await prefs.setString(syncSecretKey, syncSecret);
  }

  Future<String?> getDeviceId() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(deviceIdKey);
  }

  Future<void> setDeviceId(String deviceId) async {
    final prefs = await _prefs();
    await prefs.setString(deviceIdKey, deviceId);
  }

  Future<void> saveLastDevicePresence(
    List<Map<String, dynamic>> devices,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(lastDevicePresenceKey, jsonEncode(devices));
  }

  Future<void> saveServerConnectionStatus(String status) async {
    final prefs = await _prefs();
    await prefs.setString(serverConnectionStatusKey, status);
  }

  Future<String> loadServerConnectionStatus() async {
    final prefs = await _prefs(reload: true);
    return prefs.getString(serverConnectionStatusKey) ?? 'disconnected';
  }

  Future<List<Map<String, dynamic>>> takePendingNativeSmsQueue() async {
    final prefs = await _prefs(reload: true);
    final rawQueue = prefs.getString(pendingNativeSmsQueueKey);
    if (rawQueue == null || rawQueue.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawQueue);
      if (decoded is! List) {
        await prefs.remove(pendingNativeSmsQueueKey);
        return const [];
      }

      final queue = decoded
          .whereType<Map>()
          .map(
            (entry) => entry.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .toList(growable: false);
      await prefs.remove(pendingNativeSmsQueueKey);
      return queue;
    } catch (_) {
      await prefs.remove(pendingNativeSmsQueueKey);
      return const [];
    }
  }
}

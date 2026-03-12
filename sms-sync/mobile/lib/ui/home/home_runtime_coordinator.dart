import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../platform/runtime_support.dart';
import '../../services/app_logger.dart';
import '../../services/sms_deduplicator.dart';
import 'home_dependencies.dart';

class HomeRuntimeCoordinator {
  HomeRuntimeCoordinator({
    required this.dependencies,
    required SmsDeduplicator smsDeduplicator,
  }) : _smsDeduplicator = smsDeduplicator;

  final HomeDependencies dependencies;
  final SmsDeduplicator _smsDeduplicator;

  RawDatagramSocket? _uiSocket;
  StreamSubscription<dynamic>? _uiSocketSubscription;
  StreamSubscription<Map<String, dynamic>?>? _devicePresenceSubscription;
  StreamSubscription<Map<String, dynamic>?>? _serverStatusSubscription;
  Timer? _onlineDeviceCleanupTimer;
  Timer? _serverStatusSnapshotRetryTimer;
  String? _lastServerStatus;
  int? _lastServerStatusEpoch;
  bool _hasRealtimeServerStatusEvent = false;

  void startCore({
    required String Function() deviceIdProvider,
    required void Function(Map<String, dynamic>) onDevicePresenceUpdate,
    required void Function(String) onServerStatusUpdate,
    required void Function(String from, String body, int timestamp)
    onSmsReceived,
    required VoidCallback onCleanupDevices,
  }) {
    _setupSmsListener(
      deviceIdProvider: deviceIdProvider,
      onDevicePresenceUpdate: onDevicePresenceUpdate,
      onSmsReceived: onSmsReceived,
    );
    _setupDeviceListener(
      deviceIdProvider: deviceIdProvider,
      onDevicePresenceUpdate: onDevicePresenceUpdate,
      onServerStatusUpdate: onServerStatusUpdate,
    );
    _syncServerStatus(onServerStatusUpdate);
    _onlineDeviceCleanupTimer?.cancel();
    _onlineDeviceCleanupTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => onCleanupDevices(),
    );
  }

  Future<void> startUdpListener({
    required String Function() deviceIdProvider,
    required String Function() groupIdProvider,
    required void Function(Map<String, dynamic>) onDevicePresenceUpdate,
  }) async {
    if (!supportsAndroidSmsSyncRuntime) {
      return;
    }

    try {
      _uiSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8889);
      AppLogger.debug('UI UDP listening on port 8889');
      _uiSocketSubscription = _uiSocket!.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        final datagram = _uiSocket!.receive();
        if (datagram == null) {
          return;
        }

        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(datagram.data)),
          );
          if (data['type'] != 'device-presence') {
            return;
          }
          if (data['deviceId'] == deviceIdProvider()) {
            return;
          }
          if (data['groupId'] != groupIdProvider()) {
            return;
          }

          AppLogger.trace('UI received device presence: $data');
          onDevicePresenceUpdate({
            'deviceId': data['deviceId'],
            'deviceName': data['deviceName'] ?? '未知设备',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'source': 'lan',
          });
        } catch (e) {
          AppLogger.debug('Error parsing UDP in UI: $e');
        }
      });
    } catch (e) {
      AppLogger.debug('Failed to create UI UDP listener: $e');
    }
  }

  void _setupDeviceListener({
    required String Function() deviceIdProvider,
    required void Function(Map<String, dynamic>) onDevicePresenceUpdate,
    required void Function(String) onServerStatusUpdate,
  }) {
    if (!dependencies.supportsBackgroundService) {
      return;
    }

    final service = dependencies.createBackgroundService();
    _devicePresenceSubscription = service.on('device-presence').listen((data) {
      if (data == null) {
        return;
      }
      final deviceId = data['deviceId']?.toString();
      if (deviceId == null || deviceId.isEmpty) {
        return;
      }
      if (deviceId == deviceIdProvider()) {
        return;
      }

      AppLogger.trace('UI received device-presence event: $data');
      onDevicePresenceUpdate({
        'deviceId': deviceId,
        'deviceName': data['deviceName'] as String? ?? '未知设备',
        'timestamp': data['timestamp'] as int,
        'source': data['source'] as String? ?? 'lan',
      });
    });

    _serverStatusSubscription = service.on('server-status-change').listen((
      data,
    ) {
      if (data == null) {
        return;
      }
      AppLogger.trace('UI received server-status-change event: $data');
      final eventEpoch = data['epoch'] as int?;
      if (eventEpoch != null &&
          _lastServerStatusEpoch != null &&
          eventEpoch < _lastServerStatusEpoch!) {
        AppLogger.trace(
          'Ignored stale server-status event epoch=$eventEpoch, last=$_lastServerStatusEpoch',
        );
        return;
      }
      final status = data['status'] as String? ?? 'disconnected';
      _lastServerStatusEpoch = eventEpoch ?? _lastServerStatusEpoch;
      _hasRealtimeServerStatusEvent = true;
      if (_lastServerStatus != status) {
        AppLogger.debug(
          '[UI][ServerStatus] realtime: $_lastServerStatus -> $status (epoch=$_lastServerStatusEpoch)',
        );
      }
      _lastServerStatus = status;
      onServerStatusUpdate(status);
    });

    _requestServerStatusSnapshot(service, trigger: 'ui-startup');
    _serverStatusSnapshotRetryTimer?.cancel();
    _serverStatusSnapshotRetryTimer = Timer(
      const Duration(milliseconds: 700),
      () => _requestServerStatusSnapshot(service, trigger: 'ui-retry'),
    );
  }

  void _requestServerStatusSnapshot(
    FlutterBackgroundService service, {
    required String trigger,
  }) {
    try {
      service.invoke('request-server-status', {'trigger': trigger});
      AppLogger.trace('[UI][ServerStatus] request snapshot, trigger=$trigger');
    } catch (e) {
      AppLogger.debug(
        '[UI][ServerStatus] request snapshot failed, trigger=$trigger, error=$e',
      );
    }
  }

  Future<void> _syncServerStatus(
    void Function(String) onServerStatusUpdate,
  ) async {
    if (_hasRealtimeServerStatusEvent) {
      return;
    }
    try {
      final status = await dependencies.settingsRepository
          .loadServerConnectionStatus();
      if (_hasRealtimeServerStatusEvent) {
        AppLogger.debug(
          '[UI][ServerStatus] ignore stored sync after realtime event (stored=$status)',
        );
        return;
      }
      if (status == _lastServerStatus) {
        return;
      }
      AppLogger.debug(
        '[UI][ServerStatus] apply stored status: $_lastServerStatus -> $status',
      );
      _lastServerStatus = status;
      onServerStatusUpdate(status);
    } catch (e) {
      AppLogger.debug('Failed to sync server status from storage: $e');
    }
  }

  void _setupSmsListener({
    required String Function() deviceIdProvider,
    required void Function(Map<String, dynamic>) onDevicePresenceUpdate,
    required void Function(String from, String body, int timestamp)
    onSmsReceived,
  }) {
    final service = dependencies.supportsBackgroundService
        ? dependencies.createBackgroundService()
        : null;

    dependencies.smsMethodChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        try {
          final data = call.arguments as Map<dynamic, dynamic>;
          final from = data['from'] as String;
          final body = data['body'] as String;
          final timestamp =
              data['timestamp'] as int? ??
              DateTime.now().millisecondsSinceEpoch;
          final shouldProcess = _smsDeduplicator.shouldProcess(
            smsTimestampMs: timestamp,
          );

          AppLogger.debug('Received SMS in UI - shouldProcess: $shouldProcess');

          if (!shouldProcess) {
            AppLogger.debug('Skipping duplicate SMS in UI');
            return;
          }

          onSmsReceived(from, body, timestamp);
          service?.invoke('smsReceived', {
            'from': from,
            'body': body,
            'timestamp': timestamp,
          });
        } catch (e) {
          AppLogger.debug('Error in UI SMS listener: $e');
        }
        return;
      }

      if (call.method == 'onDevicePresence' ||
          call.method == 'onServerDevicePresence') {
        try {
          final data = call.arguments as Map<dynamic, dynamic>;
          final deviceId = data['deviceId'] as String;
          if (deviceId == deviceIdProvider()) {
            return;
          }

          final deviceName = data['deviceName'] as String;
          final timestamp =
              data['timestamp'] as int? ??
              DateTime.now().millisecondsSinceEpoch;
          onDevicePresenceUpdate({
            'deviceId': deviceId,
            'deviceName': deviceName,
            'timestamp': timestamp,
            'source': 'lan',
          });
        } catch (e) {
          AppLogger.debug('Error processing device presence in UI: $e');
        }
      }
    });
  }

  void dispose() {
    _uiSocketSubscription?.cancel();
    _uiSocket?.close();
    _devicePresenceSubscription?.cancel();
    _serverStatusSubscription?.cancel();
    _serverStatusSnapshotRetryTimer?.cancel();
    _onlineDeviceCleanupTimer?.cancel();
    dependencies.smsMethodChannel.setMethodCallHandler(null);
  }
}

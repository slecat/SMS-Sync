import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import 'background_dependencies.dart';
import '../platform/runtime_support.dart';
import '../services/app_logger.dart';

Future<void> initializeService() async {
  if (!supportsBackgroundService) {
    return;
  }

  final service = backgroundDependencies.createBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'sms_sync_service_v2',
      initialNotificationTitle: '短信同步',
      initialNotificationContent: '正在后台同步短信',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: true, onForeground: onStart),
  );
  await service.startService();
}

Future<void> ensureServiceRunning() async {
  if (!supportsBackgroundService) {
    return;
  }

  final service = backgroundDependencies.createBackgroundService();
  final isRunning = await service.isRunning();
  if (!isRunning) {
    await service.startService();
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  ui.DartPluginRegistrant.ensureInitialized();
  final dependencies = backgroundDependencies;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: '短信同步',
      content: '正在后台同步短信',
    );
  }

  var serverUrl = '';
  var groupId = 'default';
  var deviceName = '手机端';
  var syncSecret = '';
  try {
    final settings = await dependencies.settingsRepository.loadSettings();
    serverUrl = settings.serverUrl;
    groupId = settings.groupId;
    deviceName = settings.deviceName;
    syncSecret = settings.syncSecret;
  } catch (e) {
    AppLogger.debug('loadSettings failed in background runtime: $e');
  }

  var localDeviceId = 'unknown_device';
  try {
    localDeviceId = await dependencies.deviceIdService.resolveDeviceId(
      dependencies.settingsRepository,
    );
  } catch (e) {
    AppLogger.debug('resolveDeviceId failed in background runtime: $e');
  }

  final lanDevices = <String, Map<String, dynamic>>{};

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? socketSubscription;
  var currentConnectionEpoch = 0;
  String? lastNotifiedServerStatus;
  var lastReconnectProbeAtMs = 0;

  bool isCurrentConnectionEpoch(int epoch) => epoch == currentConnectionEpoch;

  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  bool sameGroupOrMissing(dynamic incomingGroupId, String expectedGroupId) {
    if (incomingGroupId == null) {
      return true;
    }
    final normalizedGroupId = incomingGroupId.toString().trim();
    return normalizedGroupId.isEmpty || normalizedGroupId == expectedGroupId;
  }

  Map<String, dynamic> signOutgoingPayload(Map<String, dynamic> payload) {
    return dependencies.messageSecurityService.signPayload(
      payload,
      secret: syncSecret,
    );
  }

  Future<void> processIncomingSms({
    required String from,
    required String body,
    required int timestamp,
    required String source,
  }) async {
    final messageId = '${localDeviceId}_$timestamp';

    final smsData = dependencies.messagePayloadFactory.sms(
      messageId: messageId,
      from: from,
      body: body,
      groupId: groupId,
      timestamp: timestamp,
    );
    final signedSmsData = signOutgoingPayload(smsData);

    try {
      await dependencies.messageTransportService.broadcastUdp(signedSmsData);
    } catch (e) {
      AppLogger.debug('Local broadcast failed for $source: $e');
    }

    if (dependencies.messageRoutingPolicy.shouldSendToServerWithLiveChannel(
      serverUrl: serverUrl,
      hasLiveChannel: channel != null,
    )) {
      try {
        await dependencies.messageTransportService.sendViaExistingChannel(
          channel,
          signedSmsData,
        );
      } catch (e) {
        AppLogger.debug('Server send failed for $source: $e');
      }
    }
  }

  Future<void> flushPendingNativeSms({required String trigger}) async {
    try {
      final pendingQueue = await dependencies.settingsRepository
          .takePendingNativeSmsQueue();
      if (pendingQueue.isEmpty) {
        return;
      }

      AppLogger.debug(
        'Processing ${pendingQueue.length} pending native SMS item(s), trigger=$trigger',
      );
      for (final sms in pendingQueue) {
        final from = sms['from']?.toString();
        final body = sms['body']?.toString();
        if (from == null || from.isEmpty || body == null || body.isEmpty) {
          continue;
        }

        final timestamp =
            sms['timestamp'] is int
                ? sms['timestamp'] as int
                : int.tryParse('${sms['timestamp']}') ??
                    DateTime.now().millisecondsSinceEpoch;
        final source = sms['source']?.toString() ?? 'native-queue';
        await processIncomingSms(
          from: from,
          body: body,
          timestamp: timestamp,
          source: source,
        );
      }
    } catch (e) {
      AppLogger.debug('Error flushing pending native SMS: $e');
    }
  }

  bool isTrustedPayload(Map<String, dynamic> payload, String source) {
    final trusted = dependencies.messageSecurityService.verifyPayload(
      payload,
      secret: syncSecret,
    );
    if (!trusted) {
      AppLogger.trace(
        'Dropped untrusted payload from $source, type: ${payload['type']}',
      );
    }
    return trusted;
  }

  bool shouldAcceptDevicePresencePayload(
    Map<String, dynamic> payload,
    String source,
  ) {
    final hasSignatureFields =
        payload.containsKey('_sig') || payload.containsKey('_sig_v');
    if (!hasSignatureFields) {
      return true;
    }
    return isTrustedPayload(payload, source);
  }

  int resolveServerPresenceTimestamp(Map<String, dynamic> payload) {
    final now = nowMs();
    final dynamic rawTimestamp = payload['timestamp'];
    if (rawTimestamp is int && rawTimestamp > 0) {
      // Guard against obviously incorrect future timestamps.
      if (rawTimestamp > now + 60000) {
        return now;
      }
      return rawTimestamp;
    }
    if (rawTimestamp is String) {
      final parsed = int.tryParse(rawTimestamp);
      if (parsed != null && parsed > 0) {
        if (parsed > now + 60000) {
          return now;
        }
        return parsed;
      }
    }
    return now;
  }

  Future<void> broadcastLanPresence({String trigger = 'periodic'}) async {
    try {
      final latestSettings = await dependencies.settingsRepository
          .loadSettings();
      final latestDeviceName = latestSettings.deviceName;
      final signedPresence = dependencies.messageSecurityService.signPayload(
        dependencies.messagePayloadFactory.devicePresence(
          deviceId: localDeviceId,
          deviceName: latestDeviceName,
          groupId: groupId,
        ),
        secret: syncSecret,
      );
      await dependencies.messageTransportService.broadcastUdp(signedPresence);
      AppLogger.trace('LAN presence sent, trigger=$trigger');
    } catch (e) {
      AppLogger.debug('Device broadcast failed ($trigger): $e');
    }
  }

  void notifyServerStatus(String status, {int? connectionEpoch}) {
    if (connectionEpoch != null && !isCurrentConnectionEpoch(connectionEpoch)) {
      AppLogger.trace(
        'Ignored stale status event from epoch=$connectionEpoch: $status',
      );
      return;
    }
    if (lastNotifiedServerStatus == status) {
      return;
    }
    lastNotifiedServerStatus = status;
    AppLogger.debug('[ServerStatus] $status');
    service.invoke('server-status-change', {
      'status': status,
      'epoch': currentConnectionEpoch,
      'timestamp': nowMs(),
    });
    unawaited(
      dependencies.settingsRepository
          .saveServerConnectionStatus(status)
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.debug('saveServerConnectionStatus failed: $error');
          }),
    );
  }

  Future<void> connectToServer(
    String newServerUrl,
    String newGroupId,
    String newDeviceName,
    String trigger,
  ) async {
    AppLogger.debug('[ServerStatus] connectToServer trigger=$trigger');
    final connectionEpoch = ++currentConnectionEpoch;

    // Cancel/close the old channel first, so stale callbacks are less likely.
    final previousSubscription = socketSubscription;
    socketSubscription = null;
    await previousSubscription?.cancel();

    final previousChannel = channel;
    channel = null;
    if (previousChannel != null) {
      try {
        previousChannel.sink.close();
      } catch (e, stackTrace) {
        AppLogger.debug('Error closing existing WebSocket: $e');
        AppLogger.debug('Stack trace: $stackTrace');
      }
    }

    if (newServerUrl.isEmpty) {
      notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
      return;
    }

    Uri? uri;
    try {
      uri = Uri.parse(newServerUrl);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        AppLogger.debug('Invalid scheme=${uri.scheme}, expected ws/wss');
        notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.debug('Invalid server URL: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
      return;
    }

    IOWebSocketChannel? newChannel;
    WebSocket? rawSocket;
    try {
      notifyServerStatus('connecting', connectionEpoch: connectionEpoch);
      rawSocket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 8));

      if (!isCurrentConnectionEpoch(connectionEpoch)) {
        try {
          rawSocket.close();
        } catch (_) {}
        return;
      }

      rawSocket.pingInterval = const Duration(seconds: 10);
      newChannel = IOWebSocketChannel(rawSocket);
      channel = newChannel;

      socketSubscription = newChannel.stream.listen(
        (message) {
          try {
            AppLogger.trace('Received WebSocket message: $message');
            final data = Map<String, dynamic>.from(jsonDecode(message));
            if ((data['type'] == 'sms' || data['type'] == 'test') &&
                !isTrustedPayload(data, 'ws')) {
              return;
            }
            if (data['type'] == 'device-presence' &&
                data['deviceId'] != localDeviceId &&
                sameGroupOrMissing(data['groupId'], newGroupId) &&
                shouldAcceptDevicePresencePayload(data, 'ws')) {
              final deviceId = data['deviceId'].toString();
              final rawName = data['deviceName']?.toString().trim();
              final name = (rawName == null || rawName.isEmpty)
                  ? '未知设备'
                  : rawName;
              final timestamp = resolveServerPresenceTimestamp(data);
              final ageMs = nowMs() - timestamp;
              if (ageMs > 15000) {
                AppLogger.debug(
                  '[DevicePresence][WS] stale presence id=$deviceId ageMs=$ageMs',
                );
              }
              AppLogger.trace('Processing server device: $deviceId, $name');

              lanDevices[deviceId] = {
                'deviceId': deviceId,
                'deviceName': name,
                'timestamp': timestamp,
                'source': 'server',
              };

              try {
                service.invoke('device-presence', {
                  'deviceId': deviceId,
                  'deviceName': name,
                  'timestamp': timestamp,
                  'source': 'server',
                });
                AppLogger.trace('device-presence event sent to UI');
              } catch (e, stackTrace) {
                AppLogger.debug('Error sending device-presence to UI: $e');
                AppLogger.debug('Stack trace: $stackTrace');
              }
            }
          } catch (e, stackTrace) {
            AppLogger.debug('Error in WebSocket message handler: $e');
            AppLogger.debug('Stack trace: $stackTrace');
          }
        },
        onError: (error, stackTrace) {
          AppLogger.debug('WebSocket onError: $error');
          AppLogger.debug('Stack trace: $stackTrace');
          if (!isCurrentConnectionEpoch(connectionEpoch)) {
            AppLogger.trace(
              'Ignored stale WebSocket onError from epoch=$connectionEpoch',
            );
            return;
          }
          if (identical(channel, newChannel)) {
            channel = null;
          }
          notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
        },
        onDone: () {
          AppLogger.debug('WebSocket onDone');
          if (!isCurrentConnectionEpoch(connectionEpoch)) {
            AppLogger.trace(
              'Ignored stale WebSocket onDone from epoch=$connectionEpoch',
            );
            return;
          }
          if (identical(channel, newChannel)) {
            channel = null;
          }
          notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
        },
        cancelOnError: true,
      );

      if (channel != newChannel || !isCurrentConnectionEpoch(connectionEpoch)) {
        AppLogger.debug(
          'WebSocket channel changed before register (epoch=$connectionEpoch)',
        );
        try {
          newChannel.sink.close();
        } catch (_) {}
        return;
      }

      newChannel.sink.add(
        jsonEncode(
          dependencies.messagePayloadFactory.register(
            deviceId: localDeviceId,
            deviceName: newDeviceName,
            groupId: newGroupId,
          ),
        ),
      );
      // Send an immediate signed presence after register so peers can
      // rediscover this device right after reconnect.
      newChannel.sink.add(
        jsonEncode(
          signOutgoingPayload(
            dependencies.messagePayloadFactory.devicePresence(
              deviceId: localDeviceId,
              deviceName: newDeviceName,
              groupId: newGroupId,
            ),
          ),
        ),
      );
      notifyServerStatus('connected', connectionEpoch: connectionEpoch);
    } catch (e, stackTrace) {
      AppLogger.debug('WebSocket connect flow failed: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      if (!isCurrentConnectionEpoch(connectionEpoch)) {
        try {
          newChannel?.sink.close();
        } catch (_) {}
        try {
          rawSocket?.close();
        } catch (_) {}
        return;
      }
      if (identical(channel, newChannel)) {
        channel = null;
      }
      try {
        newChannel?.sink.close();
      } catch (_) {}
      try {
        rawSocket?.close();
      } catch (_) {}
      notifyServerStatus('disconnected', connectionEpoch: connectionEpoch);
    }
  }

  final presenceSocket = await RawDatagramSocket.bind(
    InternetAddress.anyIPv4,
    8888,
  );
  AppLogger.debug(
    'UDP listening on port 8888, address: ${presenceSocket.address}',
  );
  presenceSocket.listen((RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      final datagram = presenceSocket.receive();
      if (datagram != null) {
        AppLogger.trace(
          'Received UDP from: ${datagram.address}:${datagram.port}, data: ${utf8.decode(datagram.data)}',
        );
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(datagram.data)),
          );
          if (data['type'] == 'sms' && !isTrustedPayload(data, 'lan')) {
            return;
          }
          if (data['type'] == 'device-presence' &&
              data['deviceId'] != localDeviceId &&
              data['groupId'] == groupId) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final deviceName = data['deviceName'] ?? '未知设备';
            AppLogger.trace(
              'Adding LAN device: ${data['deviceId']}, $deviceName',
            );
            lanDevices[data['deviceId']] = {
              'deviceId': data['deviceId'],
              'deviceName': deviceName,
              'timestamp': now,
              'source': 'lan',
            };
            // Send event to UI
            service.invoke('device-presence', {
              'deviceId': data['deviceId'],
              'deviceName': deviceName,
              'timestamp': now,
              'source': 'lan',
            });
          } else if (data['type'] == 'sms') {
            if (dependencies.messageRoutingPolicy
                .shouldSendToServerWithLiveChannel(
                  serverUrl: serverUrl,
                  hasLiveChannel: channel != null,
                )) {
              try {
                await dependencies.messageTransportService
                    .sendViaExistingChannel(
                      channel,
                      Map<String, dynamic>.from(data),
                    );
              } catch (e) {
                AppLogger.debug('Server send failed: $e');
              }
            }
          }
        } catch (e) {
          AppLogger.debug('Error parsing presence: $e');
        }
      }
    }
  });

  final cleanupTimer = Timer.periodic(const Duration(seconds: 3), (
    timer,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    lanDevices.removeWhere(
      (id, device) => now - (device['timestamp'] as int) > 30000,
    );

    AppLogger.trace(
      'Saving devices to SharedPreferences: ${lanDevices.values.toList()}',
    );
    await dependencies.settingsRepository.saveLastDevicePresence(
      lanDevices.values.toList(),
    );
  });

  final wsPresenceTimer = Timer.periodic(const Duration(seconds: 5), (
    timer,
  ) async {
    if (channel != null) {
      try {
        await dependencies.messageTransportService.sendViaExistingChannel(
          channel,
          signOutgoingPayload(
            dependencies.messagePayloadFactory.devicePresence(
              deviceId: localDeviceId,
              deviceName: deviceName,
              groupId: groupId,
            ),
          ),
        );
      } catch (e) {
        AppLogger.debug('WebSocket device presence failed: $e');
        try {
          channel?.sink.close();
        } catch (_) {}
        channel = null;
        notifyServerStatus('disconnected');
      }
    }
  });

  // Heartbeat-style probe:
  // keep attempts low-frequency and only when currently disconnected.
  final reconnectProbeTimer = Timer.periodic(const Duration(seconds: 5), (
    timer,
  ) async {
    if (serverUrl.trim().isEmpty) {
      return;
    }
    if (channel != null || lastNotifiedServerStatus == 'connecting') {
      return;
    }
    final now = nowMs();
    // Probe every 12s at most to avoid aggressive reconnect storms.
    if (now - lastReconnectProbeAtMs < 12000) {
      return;
    }
    lastReconnectProbeAtMs = now;
    await connectToServer(serverUrl, groupId, deviceName, 'heartbeat-probe');
  });

  final lanPresenceTimer = Timer.periodic(const Duration(seconds: 5), (
    timer,
  ) async {
    await broadcastLanPresence();
  });

  final pendingNativeSmsTimer = Timer.periodic(const Duration(seconds: 3), (
    timer,
  ) async {
    await flushPendingNativeSms(trigger: 'periodic');
  });

  // Listen for SMS from UI isolate via ServiceInstance
  final smsReceivedSubscription = service.on('smsReceived').listen((
    data,
  ) async {
    try {
      final from = data!['from'] as String;
      final body = data['body'] as String;
      final timestamp =
          data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      await processIncomingSms(
        from: from,
        body: body,
        timestamp: timestamp,
        source: 'ui-service-event',
      );
    } catch (e) {
      AppLogger.debug('Error processing SMS in background: $e');
    }
  });

  // Listen for reconnect-server event from UI
  final reconnectSubscription = service.on('reconnect-server').listen((
    event,
  ) async {
    try {
      // Reconnect to server with new settings
      final newSettings = await dependencies.settingsRepository.loadSettings();
      final newServerUrl = newSettings.serverUrl;
      final newGroupId = newSettings.groupId;
      final newDeviceName = newSettings.deviceName;
      final newSyncSecret = newSettings.syncSecret;
      // Update local variables
      serverUrl = newServerUrl;
      groupId = newGroupId;
      deviceName = newDeviceName;
      syncSecret = newSyncSecret;

      // Reconnect
      await connectToServer(
        newServerUrl,
        newGroupId,
        newDeviceName,
        'manual-reconnect-event',
      );
    } catch (e, stackTrace) {
      AppLogger.debug('Error in reconnect-server handler: $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
  });

  unawaited(connectToServer(serverUrl, groupId, deviceName, 'startup'));
  unawaited(broadcastLanPresence(trigger: 'startup'));
  unawaited(flushPendingNativeSms(trigger: 'startup'));

  late final StreamSubscription<dynamic> stopServiceSubscription;
  stopServiceSubscription = service.on('stopService').listen((event) async {
    cleanupTimer.cancel();
    wsPresenceTimer.cancel();
    reconnectProbeTimer.cancel();
    lanPresenceTimer.cancel();
    pendingNativeSmsTimer.cancel();
    await socketSubscription?.cancel();
    await smsReceivedSubscription.cancel();
    await reconnectSubscription.cancel();
    await stopServiceSubscription.cancel();
    try {
      channel?.sink.close();
    } catch (_) {}
    presenceSocket.close();
    service.stopSelf();
  });
}

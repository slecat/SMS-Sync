import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
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
      notificationChannelId: 'sms_sync_channel',
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
  final dependencies = backgroundDependencies;

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: '短信同步',
      content: '正在后台同步短信',
    );
  }

  final settings = await dependencies.settingsRepository.loadSettings();
  final localDeviceId = await dependencies.deviceIdService.resolveDeviceId(
    dependencies.settingsRepository,
  );
  var serverUrl = settings.serverUrl;
  var groupId = settings.groupId;
  var deviceName = settings.deviceName;
  var syncSecret = settings.syncSecret;

  final lanDevices = <String, Map<String, dynamic>>{};

  WebSocketChannel? channel;
  StreamSubscription<dynamic>? socketSubscription;
  Map<String, dynamic> signOutgoingPayload(Map<String, dynamic> payload) {
    return dependencies.messageSecurityService.signPayload(
      payload,
      secret: syncSecret,
    );
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

  void notifyServerStatus(String status) {
    AppLogger.debug('[ServerStatus] $status');
    service.invoke('server-status-change', {'status': status});
    unawaited(
      dependencies.settingsRepository
          .saveServerConnectionStatus(status)
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.debug('saveServerConnectionStatus failed: $error');
          }),
    );
  }

  // Function to connect to WebSocket server - GRADUAL RESTORATION
  Future<void> connectToServer(
    String newServerUrl,
    String newGroupId,
    String newDeviceName,
  ) async {
    // Close existing connection if exists
    if (channel != null) {
      try {
        channel!.sink.close();
      } catch (e, stackTrace) {
        AppLogger.debug('Error closing existing WebSocket: $e');
        AppLogger.debug('Stack trace: $stackTrace');
      }
      channel = null;
    }
    socketSubscription?.cancel();
    socketSubscription = null;

    if (newServerUrl.isEmpty) {
      notifyServerStatus('disconnected');
      return;
    }

    // Validate and parse the URL first
    Uri? uri;
    try {
      uri = Uri.parse(newServerUrl);
      // Ensure it's a ws or wss scheme
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        AppLogger.debug('Invalid scheme=${uri.scheme}, expected ws/wss');
        notifyServerStatus('disconnected');
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.debug('Invalid server URL: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      notifyServerStatus('disconnected');
      return;
    }

    // Now try to connect - with ALL errors caught!
    IOWebSocketChannel? newChannel;
    WebSocket? rawSocket;
    try {
      notifyServerStatus('connecting');
      rawSocket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 8));
      rawSocket.pingInterval = const Duration(seconds: 20);
      newChannel = IOWebSocketChannel(rawSocket);
      channel = newChannel;

      // Listen for all events with maximum error handling
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
                data['groupId'] == newGroupId) {
              final deviceId = data['deviceId'];
              final name = data['deviceName'] ?? '未知设备';
              final timestamp = data['timestamp'] as int;
              AppLogger.trace('Processing server device: $deviceId, $name');

              // Update internal lanDevices map
              lanDevices[deviceId] = {
                'deviceId': deviceId,
                'deviceName': name,
                'timestamp': timestamp,
                'source': 'server',
              };

              // Send event to UI
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
          if (identical(channel, newChannel)) {
            channel = null;
          }
          notifyServerStatus('disconnected');
        },
        onDone: () {
          AppLogger.debug('WebSocket onDone');
          if (identical(channel, newChannel)) {
            channel = null;
          }
          notifyServerStatus('disconnected');
        },
        cancelOnError: true,
      );
      if (channel != newChannel) {
        AppLogger.debug('WebSocket channel changed before register');
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
      notifyServerStatus('connected');
    } catch (e, stackTrace) {
      AppLogger.debug('WebSocket connect flow failed: $e');
      AppLogger.debug('Stack trace: $stackTrace');
      if (identical(channel, newChannel)) {
        channel = null;
      }
      try {
        newChannel?.sink.close();
      } catch (_) {}
      try {
        rawSocket?.close();
      } catch (_) {}
      notifyServerStatus('disconnected');
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
      }
    }
  });

  final lanPresenceTimer = Timer.periodic(const Duration(seconds: 5), (
    timer,
  ) async {
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
    } catch (e) {
      AppLogger.debug('Device broadcast failed: $e');
    }
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
        AppLogger.debug('Local broadcast failed: $e');
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
          AppLogger.debug('Server send failed: $e');
        }
      }
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
      await connectToServer(newServerUrl, newGroupId, newDeviceName);
    } catch (e, stackTrace) {
      AppLogger.debug('Error in reconnect-server handler: $e');
      AppLogger.debug('Stack trace: $stackTrace');
    }
  });

  unawaited(connectToServer(serverUrl, groupId, deviceName));

  late final StreamSubscription<dynamic> stopServiceSubscription;
  stopServiceSubscription = service.on('stopService').listen((event) async {
    cleanupTimer.cancel();
    wsPresenceTimer.cancel();
    lanPresenceTimer.cancel();
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

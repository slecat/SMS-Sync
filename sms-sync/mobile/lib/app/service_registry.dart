import 'package:flutter/services.dart';

import '../platform/channels.dart';
import '../services/device_id_service.dart';
import '../services/message_payload_factory.dart';
import '../services/message_routing_policy.dart';
import '../services/message_security_service.dart';
import '../services/message_transport_service.dart';
import '../services/settings_repository.dart';

class AppServices {
  AppServices({
    required this.settingsRepository,
    required this.deviceIdService,
    required this.messagePayloadFactory,
    required this.messageTransportService,
    required this.messageRoutingPolicy,
    required this.messageSecurityService,
    required this.platformMethodChannel,
    required this.smsMethodChannel,
  });

  factory AppServices.createDefault() {
    final settingsRepository = SettingsRepository();
    return AppServices(
      settingsRepository: settingsRepository,
      deviceIdService: DeviceIdService(platformChannel: platformChannel),
      messagePayloadFactory: MessagePayloadFactory(),
      messageTransportService: MessageTransportService(),
      messageRoutingPolicy: MessageRoutingPolicy(),
      messageSecurityService: MessageSecurityService(),
      platformMethodChannel: platformChannel,
      smsMethodChannel: smsChannel,
    );
  }

  final SettingsRepository settingsRepository;
  final DeviceIdService deviceIdService;
  final MessagePayloadFactory messagePayloadFactory;
  final MessageTransportService messageTransportService;
  final MessageRoutingPolicy messageRoutingPolicy;
  final MessageSecurityService messageSecurityService;
  final MethodChannel platformMethodChannel;
  final MethodChannel smsMethodChannel;
}

AppServices _appServices = AppServices.createDefault();

AppServices get appServices => _appServices;

void configureAppServices(AppServices services) {
  _appServices = services;
}

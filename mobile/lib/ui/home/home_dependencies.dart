import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../app/service_registry.dart';
import '../../platform/runtime_support.dart';
import '../../services/device_id_service.dart';
import '../../services/message_payload_factory.dart';
import '../../services/message_routing_policy.dart';
import '../../services/message_security_service.dart';
import '../../services/message_transport_service.dart';
import '../../services/settings_repository.dart';

typedef BackgroundServiceFactory = FlutterBackgroundService Function();

class HomeDependencies {
  const HomeDependencies({
    required this.settingsRepository,
    required this.deviceIdService,
    required this.messagePayloadFactory,
    required this.messageTransportService,
    required this.messageRoutingPolicy,
    required this.messageSecurityService,
    required this.smsMethodChannel,
    required this.supportsBackgroundService,
    required this.createBackgroundService,
  });

  final SettingsRepository settingsRepository;
  final DeviceIdService deviceIdService;
  final MessagePayloadFactory messagePayloadFactory;
  final MessageTransportService messageTransportService;
  final MessageRoutingPolicy messageRoutingPolicy;
  final MessageSecurityService messageSecurityService;
  final MethodChannel smsMethodChannel;
  final bool supportsBackgroundService;
  final BackgroundServiceFactory createBackgroundService;
}

HomeDependencies createDefaultHomeDependencies() {
  final services = appServices;
  return HomeDependencies(
    settingsRepository: services.settingsRepository,
    deviceIdService: services.deviceIdService,
    messagePayloadFactory: services.messagePayloadFactory,
    messageTransportService: services.messageTransportService,
    messageRoutingPolicy: services.messageRoutingPolicy,
    messageSecurityService: services.messageSecurityService,
    smsMethodChannel: services.smsMethodChannel,
    supportsBackgroundService: supportsBackgroundService,
    createBackgroundService: FlutterBackgroundService.new,
  );
}

import 'package:flutter/material.dart';

import 'home/home_action_coordinator.dart';
import 'home/home_bottom_nav_bar.dart';
import 'home/home_dependencies.dart';
import 'home/home_runtime_coordinator.dart';
import 'home/home_setup_coordinator.dart';
import 'home/home_snack_bar.dart';
import 'home/home_view_state.dart';
import 'home/messages_tab.dart';
import 'home/settings_tab.dart';
import 'home/sync_settings_tab.dart';
import '../services/app_logger.dart';
import '../services/sms_deduplicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _groupIdController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _syncSecretController = TextEditingController();
  HomeViewState _viewState = HomeViewState.initial();
  final HomeDependencies _dependencies = createDefaultHomeDependencies();
  late final HomeSetupCoordinator _setupCoordinator = HomeSetupCoordinator(
    dependencies: _dependencies,
  );
  final SmsDeduplicator _smsDeduplicator = SmsDeduplicator(minIntervalMs: 2000);
  late final HomeActionCoordinator _actionCoordinator = HomeActionCoordinator(
    dependencies: _dependencies,
  );
  late final HomeRuntimeCoordinator _runtimeCoordinator =
      HomeRuntimeCoordinator(
        dependencies: _dependencies,
        smsDeduplicator: _smsDeduplicator,
      );
  static const int _deviceTimeout = 8000;
  static final RegExp _schemePrefixPattern = RegExp(
    r'^[a-zA-Z][a-zA-Z\d+\-.]*://',
  );
  bool _hasLiveServerStatus = false;

  @override
  void initState() {
    super.initState();
    _runtimeCoordinator.startCore(
      deviceIdProvider: () => _viewState.deviceId,
      onDevicePresenceUpdate: _onDevicePresenceUpdate,
      onServerStatusUpdate: (status) {
        if (!mounted) {
          return;
        }
        _hasLiveServerStatus = true;
        AppLogger.debug('[UI][ServerStatus] apply live status: $status');
        setState(() {
          _viewState = _viewState.withServerStatus(status);
        });
      },
      onSmsReceived: (from, body, _) {
        if (!mounted) {
          return;
        }
        setState(() {
          _viewState = _viewState.withReceivedSms(from: from, body: body);
        });
      },
      onCleanupDevices: _cleanupStaleDevices,
    );
    _init().then((_) {
      _runtimeCoordinator.startUdpListener(
        deviceIdProvider: () => _viewState.deviceId,
        groupIdProvider: () => _groupIdController.text,
        onDevicePresenceUpdate: _onDevicePresenceUpdate,
      );
    });
  }

  Future<void> _init() async {
    final result = await _setupCoordinator.initialize();
    if (result.settingsError != null) {
      AppLogger.debug('Load preferences failed: ${result.settingsError}');
    }
    if (result.permissionError != null) {
      AppLogger.debug('Permission request failed: ${result.permissionError}');
    }
    if (mounted) {
      final bootstrapStatus = result.data.serverStatus;
      final effectiveServerStatus = _hasLiveServerStatus
          ? _viewState.serverStatus
          : bootstrapStatus;
      if (_hasLiveServerStatus && bootstrapStatus != _viewState.serverStatus) {
        AppLogger.debug(
          '[UI][ServerStatus] skip bootstrap status "$bootstrapStatus", keep live "${_viewState.serverStatus}"',
        );
      }
      setState(() {
        _viewState = _viewState.withSetupData(
          deviceId: result.data.deviceId,
          groupId: result.data.groupId,
          serverUrl: result.data.serverUrl,
          deviceName: result.data.deviceName,
          syncSecret: result.data.syncSecret,
          serverStatus: effectiveServerStatus,
        );
        _groupIdController.text = result.data.groupId;
        _serverUrlController.text = _toServerAddressInput(
          result.data.serverUrl,
        );
        _deviceNameController.text = result.data.deviceName;
        _syncSecretController.text = result.data.syncSecret;
      });
    }
  }

  void _onDevicePresenceUpdate(Map<String, dynamic> device) {
    if (!mounted) {
      return;
    }
    setState(() {
      _viewState = _viewState.withDevicePresence(
        device,
        localDeviceId: _viewState.deviceId,
      );
    });
  }

  void _cleanupStaleDevices() {
    if (!mounted) {
      return;
    }
    final before = _viewState.onlineDevices.length;
    setState(() {
      _viewState = _viewState.withoutStaleDevices(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        timeoutMs: _deviceTimeout,
      );
    });
    final removed = before - _viewState.onlineDevices.length;
    if (removed > 0) {
      AppLogger.debug(
        '[UI][Devices] cleaned stale devices: removed=$removed, remain=${_viewState.onlineDevices.length}',
      );
    }
  }

  Future<void> _savePreferences() async {
    final syncSecret = _syncSecretController.text.trim();
    if (syncSecret.isEmpty) {
      HomeSnackBar.show(context, '同步密钥不能为空', tone: HomeSnackBarTone.error);
      return;
    }

    await _actionCoordinator.savePreferences(
      groupId: _groupIdController.text,
      serverUrl: _toServerUrl(_serverUrlController.text),
      deviceName: _deviceNameController.text,
      syncSecret: syncSecret,
    );

    if (mounted) {
      HomeSnackBar.show(context, '设置已保存');
    }
  }

  Future<void> _sendTest() async {
    final result = await _actionCoordinator.sendTest(
      deviceId: _viewState.deviceId,
    );

    if (!mounted) {
      return;
    }

    if (result.status == SendTestStatus.localFailed) {
      HomeSnackBar.show(
        context,
        '本地发送失败：${result.error}',
        tone: HomeSnackBarTone.error,
      );
      return;
    }

    if (result.status == SendTestStatus.serverFailed) {
      HomeSnackBar.show(
        context,
        '服务器发送失败：${result.error}',
        tone: HomeSnackBarTone.error,
      );
      return;
    }

    if (result.status == SendTestStatus.success) {
      HomeSnackBar.show(context, '测试消息已发送');
    }
  }

  Future<void> _readLatestSms() async {
    final result = await _actionCoordinator.readLatestSms(
      deviceId: _viewState.deviceId,
    );
    if (!mounted) {
      return;
    }

    if (result.status == ReadLatestSmsStatus.success) {
      setState(() {
        _viewState = _viewState.withLatestSms(
          from: result.from,
          body: result.body,
        );
      });
      HomeSnackBar.show(context, '已读取并发送最新短信');
      return;
    }

    if (result.status == ReadLatestSmsStatus.notFound) {
      HomeSnackBar.show(context, '没有找到短信', tone: HomeSnackBarTone.warning);
      return;
    }

    if (result.status == ReadLatestSmsStatus.invalidPayload) {
      HomeSnackBar.show(context, '短信内容不完整', tone: HomeSnackBarTone.warning);
      return;
    }

    HomeSnackBar.show(
      context,
      '读取短信失败：${result.error}',
      tone: HomeSnackBarTone.error,
    );
  }

  String _toServerUrl(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final addressOnly = normalized.replaceFirst(_schemePrefixPattern, '');
    return 'ws://$addressOnly';
  }

  String _toServerAddressInput(String serverUrl) {
    final normalized = serverUrl.trim();
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceFirst(_schemePrefixPattern, '');
  }

  @override
  void dispose() {
    _runtimeCoordinator.dispose();
    _groupIdController.dispose();
    _serverUrlController.dispose();
    _deviceNameController.dispose();
    _syncSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final currentIndex = _viewState.currentIndex.clamp(0, 2);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          MessagesTab(
            onlineDevices: _viewState.onlineDevices,
            serverStatus: _viewState.serverStatus,
            latestSmsFrom: _viewState.latestSmsFrom,
            latestSmsBody: _viewState.latestSmsBody,
            smsCount: _viewState.smsCount,
            verificationCodeCount: _viewState.verificationCodeCount,
            onReadLatestSms: _readLatestSms,
            onSendTest: _sendTest,
          ),
          SyncSettingsTab(
            serverStatus: _viewState.serverStatus,
            groupIdController: _groupIdController,
            serverUrlController: _serverUrlController,
            deviceNameController: _deviceNameController,
            syncSecretController: _syncSecretController,
            onSavePreferences: _savePreferences,
          ),
          SettingsTab(deviceId: _viewState.deviceId),
        ],
      ),
      bottomNavigationBar: HomeBottomNavBar(
        currentIndex: currentIndex,
        smsCount: _viewState.smsCount,
        onTabSelected: (index) {
          setState(() {
            _viewState = _viewState.withCurrentIndex(index);
          });
        },
      ),
    );
  }
}

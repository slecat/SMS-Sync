import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/service_registry.dart';
import '../../platform/channels.dart';
import '../../platform/native_relay_channel.dart';
import '../../platform/runtime_support.dart';
import '../../services/app_update_service.dart';
import 'home_snack_bar.dart';
import 'update_download_route_sheet.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> with WidgetsBindingObserver {
  final AppUpdateService _appUpdateService = appServices.appUpdateService;

  PermissionStatus _smsPermission = PermissionStatus.denied;
  PermissionStatus _notificationPermission = PermissionStatus.denied;
  PermissionStatus _batteryPermission = PermissionStatus.denied;
  bool _isNotificationListenerEnabled = false;
  bool _isRefreshing = true;
  bool _isOpeningNotificationListenerSettings = false;
  bool _forwardVerificationCodeOnly = false;
  bool _isSavingForwardingSetting = false;
  bool _isCheckingUpdate = false;
  bool _isInstallingUpdate = false;
  AppUpdateState _updateState = AppUpdateState.initial();
  AppVersionInfo? _currentVersionInfo;
  NativeRelayHealth? _relayHealth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateState = _appUpdateService.state;
    _loadForwardingSettings();
    _refreshPermissions();
    _refreshRelayHealth();
    _runStartupUpdateCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
      _refreshRelayHealth();
    }
  }

  Future<void> _refreshRelayHealth() async {
    if (!supportsAndroidSmsSyncRuntime) {
      return;
    }
    try {
      final health = await const NativeRelayChannel().readHealth();
      if (mounted) {
        setState(() {
          _relayHealth = health;
        });
      }
    } catch (error) {
      debugPrint('Failed to read native relay health: $error');
    }
  }

  Future<void> _runStartupUpdateCheck() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await _checkForUpdates(silent: true);
  }

  Future<void> _refreshPermissions() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isRefreshing = true;
    });

    if (!supportsAndroidSmsSyncRuntime) {
      if (!mounted) {
        return;
      }
      setState(() {
        _smsPermission = PermissionStatus.granted;
        _notificationPermission = PermissionStatus.granted;
        _batteryPermission = PermissionStatus.granted;
        _isNotificationListenerEnabled = true;
        _isRefreshing = false;
      });
      return;
    }

    final smsStatus = await Permission.sms.status;
    final notificationStatus = await Permission.notification.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    bool isNotificationListenerEnabled = false;

    try {
      isNotificationListenerEnabled =
          await platformChannel.invokeMethod<bool>(
            'isNotificationListenerEnabled',
          ) ??
          false;
    } on PlatformException {
      isNotificationListenerEnabled = false;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _smsPermission = smsStatus;
      _notificationPermission = notificationStatus;
      _batteryPermission = batteryStatus;
      _isNotificationListenerEnabled = isNotificationListenerEnabled;
      _isRefreshing = false;
    });
  }

  Future<void> _loadForwardingSettings() async {
    try {
      final settings = await appServices.settingsRepository.loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardVerificationCodeOnly = settings.forwardVerificationCodeOnly;
      });
    } catch (error) {
      debugPrint('Failed to load forwarding settings: $error');
    }
  }

  Future<AppVersionInfo> _loadCurrentVersionInfo() async {
    if (_currentVersionInfo != null) {
      return _currentVersionInfo!;
    }

    final result = await platformChannel.invokeMethod<Map<Object?, Object?>>(
      'getAppVersionInfo',
    );
    final version = (result?['version'] ?? '').toString().trim();
    final buildNumber =
        int.tryParse((result?['buildNumber'] ?? '0').toString()) ?? 0;
    if (version.isEmpty) {
      throw StateError('无法读取当前应用版本');
    }

    _currentVersionInfo = AppVersionInfo(
      version: version,
      buildNumber: buildNumber,
    );
    return _currentVersionInfo!;
  }

  Future<void> _checkForUpdates({required bool silent}) async {
    if (_isCheckingUpdate) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final currentVersion = await _loadCurrentVersionInfo();
      final nextState = await _appUpdateService.checkForUpdates(
        currentVersion: currentVersion,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _updateState = nextState;
      });

      if (!silent) {
        _showUpdateCheckFeedback(nextState);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final nextState = _updateState.copyWith(
        status: AppUpdateStatus.error,
        message: error.toString(),
      );
      setState(() {
        _updateState = nextState;
      });
      if (!silent) {
        HomeSnackBar.show(context, '检查更新失败', tone: HomeSnackBarTone.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  void _showUpdateCheckFeedback(AppUpdateState state) {
    if (state.status == AppUpdateStatus.upToDate) {
      HomeSnackBar.show(context, '当前已经是最新版本');
      return;
    }
    if (state.status == AppUpdateStatus.available) {
      HomeSnackBar.show(context, '发现新版本，可以开始下载');
      return;
    }
    if (state.status == AppUpdateStatus.error) {
      HomeSnackBar.show(context, '检查更新失败', tone: HomeSnackBarTone.error);
    }
  }

  Future<void> _downloadOrInstallUpdate() async {
    if (_isInstallingUpdate || _isCheckingUpdate) {
      return;
    }

    if (_updateState.status == AppUpdateStatus.readyToInstall &&
        _updateState.downloadedFilePath != null) {
      await _installDownloadedApk();
      return;
    }

    final latestRelease = _updateState.latestRelease;
    if (latestRelease == null) {
      return;
    }

    final selectedOption = await _selectDownloadOption(latestRelease);
    if (_updateState.status != AppUpdateStatus.readyToInstall &&
        latestRelease.downloadOptions.isNotEmpty &&
        selectedOption == null) {
      return;
    }

    final nextState = await _appUpdateService.downloadUpdate(
      release: latestRelease,
      selectedOption: selectedOption,
      onStateChanged: (state) {
        if (!mounted) {
          return;
        }
        setState(() {
          _updateState = state;
        });
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _updateState = nextState;
    });

    if (nextState.status == AppUpdateStatus.readyToInstall) {
      await _installDownloadedApk();
      return;
    }

    if (nextState.status == AppUpdateStatus.error) {
      HomeSnackBar.show(context, '下载更新失败', tone: HomeSnackBarTone.error);
    }
  }

  Future<AppDownloadOption?> _selectDownloadOption(AppRelease release) async {
    final options = release.downloadOptions
        .where((option) => option.url.trim().isNotEmpty)
        .toList(growable: false);

    if (options.isEmpty) {
      return null;
    }

    if (options.length == 1) {
      return options.first;
    }

    return showModalBottomSheet<AppDownloadOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return UpdateDownloadRouteSheet(
          options: options,
          onSelected: (option) {
            Navigator.of(context).pop(option);
          },
        );
      },
    );
  }

  Future<void> _installDownloadedApk() async {
    final downloadedFilePath = _updateState.downloadedFilePath;
    if (downloadedFilePath == null || downloadedFilePath.isEmpty) {
      return;
    }
    if (_isInstallingUpdate) {
      return;
    }

    setState(() {
      _isInstallingUpdate = true;
    });

    try {
      final canInstall =
          await platformChannel.invokeMethod<bool>(
            'canRequestPackageInstalls',
          ) ??
          false;
      if (!canInstall) {
        await platformChannel.invokeMethod<bool>(
          'openInstallUnknownAppSourcesSettings',
        );
        if (mounted) {
          HomeSnackBar.show(
            context,
            '请允许安装未知应用后重试',
            tone: HomeSnackBarTone.warning,
          );
        }
        return;
      }

      final success =
          await platformChannel.invokeMethod<bool>('installDownloadedApk', {
            'filePath': downloadedFilePath,
          }) ??
          false;
      if (!mounted) {
        return;
      }

      if (success) {
        HomeSnackBar.show(context, '已启动系统安装器');
      } else {
        HomeSnackBar.show(context, '启动安装失败', tone: HomeSnackBarTone.error);
      }
    } on PlatformException {
      if (mounted) {
        HomeSnackBar.show(context, '启动安装失败', tone: HomeSnackBarTone.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstallingUpdate = false;
        });
      }
    }
  }

  Future<void> _requestSmsPermission() async {
    await Permission.sms.request();
    await _refreshPermissions();
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
    await _refreshPermissions();
  }

  Future<void> _requestBatteryPermission() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refreshPermissions();
    if (!_batteryPermission.isGranted) {
      await openAppSettings();
    }
  }

  Future<void> _openNotificationListenerSettings() async {
    if (_isOpeningNotificationListenerSettings) {
      return;
    }
    setState(() {
      _isOpeningNotificationListenerSettings = true;
    });
    try {
      await platformChannel.invokeMethod<bool>(
        'openNotificationListenerSettings',
      );
    } on PlatformException catch (error) {
      debugPrint('Failed to open notification listener settings: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningNotificationListenerSettings = false;
        });
      }
    }
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
  }

  Future<void> _setForwardVerificationCodeOnly(bool value) async {
    if (_isSavingForwardingSetting) {
      return;
    }

    final previousValue = _forwardVerificationCodeOnly;
    setState(() {
      _forwardVerificationCodeOnly = value;
      _isSavingForwardingSetting = true;
    });

    try {
      await appServices.settingsRepository.saveForwardVerificationCodeOnly(
        value,
      );

      if (supportsAndroidSmsSyncRuntime) {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }
        service.invoke('reconnect-server');
      }

      if (!mounted) {
        return;
      }
      HomeSnackBar.show(context, value ? '已开启只转发验证码消息' : '已关闭只转发验证码消息');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _forwardVerificationCodeOnly = previousValue;
      });
      HomeSnackBar.show(context, '保存转发设置失败', tone: HomeSnackBarTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingForwardingSetting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final smsVisual = _permissionVisual(_smsPermission);
    final notificationVisual = _permissionVisual(_notificationPermission);
    final batteryVisual = _permissionVisual(_batteryPermission);
    final listenerVisual = _listenerVisual(_isNotificationListenerEnabled);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Color(0xFF173C36),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '权限状态、版本更新与设备信息',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF173C36).withValues(alpha: 0.58),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '应用更新',
              icon: Icons.system_update_rounded,
              trailing: IconButton(
                onPressed: _isCheckingUpdate
                    ? null
                    : () {
                        _checkForUpdates(silent: false);
                      },
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF2F7658),
                        size: 18,
                      ),
                tooltip: '检查更新',
              ),
              children: [
                _UpdateSummary(
                  currentVersionLabel: _formatVersionLabel(
                    _updateState.currentVersion,
                    _updateState.currentBuildNumber,
                  ),
                  latestVersionLabel: _formatVersionLabel(
                    _updateState.latestRelease?.version,
                    _updateState.latestRelease?.buildNumber ?? 0,
                    emptyLabel: '尚未检测',
                  ),
                  statusText: _updateStatusText(),
                  statusColor: _updateStatusColor(),
                  progress: _updateState.downloadProgress,
                  showProgress:
                      _updateState.status == AppUpdateStatus.downloading ||
                      _updateState.downloadProgress > 0,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isCheckingUpdate
                        ? null
                        : () {
                            _checkForUpdates(silent: false);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F7658),
                      side: BorderSide(color: const Color(0xFFD8D4CC)),
                    ),
                    child: Text(_isCheckingUpdate ? '检查中...' : '手动检查更新'),
                  ),
                ),
                if (_shouldShowUpdateActionButton()) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          (_updateState.status == AppUpdateStatus.downloading ||
                              _isInstallingUpdate)
                          ? null
                          : _downloadOrInstallUpdate,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F7658),
                      ),
                      child: Text(_updateActionLabel()),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '消息转发',
              icon: Icons.sms_outlined,
              children: [
                _SwitchItem(
                  icon: Icons.password_rounded,
                  title: '只转发验证码消息',
                  description: supportsAndroidSmsSyncRuntime
                      ? '开启后，普通短信不会同步到其他设备。'
                      : '当前平台不支持短信同步，该设置不会生效。',
                  value: _forwardVerificationCodeOnly,
                  onChanged: _isSavingForwardingSetting
                      ? null
                      : _setForwardVerificationCodeOnly,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '权限与监听',
              icon: Icons.shield_rounded,
              trailing: IconButton(
                onPressed: _isRefreshing ? null : _refreshPermissions,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF2F7658),
                        size: 18,
                      ),
                tooltip: '刷新状态',
              ),
              children: [
                _PermissionItem(
                  icon: Icons.notification_important_rounded,
                  title: '通知监听',
                  description: '用于读取短信应用通知中的验证码内容，兼容系统隐藏短信。',
                  statusText: listenerVisual.label,
                  statusColor: listenerVisual.color,
                  statusIcon: listenerVisual.icon,
                  actionLabel: _isNotificationListenerEnabled
                      ? '去设置'
                      : (_isOpeningNotificationListenerSettings
                            ? '打开中...'
                            : '去开启'),
                  onAction: _openNotificationListenerSettings,
                ),
                const SizedBox(height: 8),
                _PermissionItem(
                  icon: Icons.sms_rounded,
                  title: '短信权限',
                  description: '读取和接收标准短信数据库中的内容。',
                  statusText: smsVisual.label,
                  statusColor: smsVisual.color,
                  statusIcon: smsVisual.icon,
                  actionLabel: _smsPermission.isGranted ? '去设置' : '去授权',
                  onAction: _smsPermission.isGranted
                      ? _openSystemSettings
                      : _requestSmsPermission,
                ),
                const SizedBox(height: 8),
                _PermissionItem(
                  icon: Icons.notifications_rounded,
                  title: '通知权限',
                  description: '用于显示前台服务通知。',
                  statusText: notificationVisual.label,
                  statusColor: notificationVisual.color,
                  statusIcon: notificationVisual.icon,
                  actionLabel: _notificationPermission.isGranted
                      ? '去设置'
                      : '去授权',
                  onAction: _notificationPermission.isGranted
                      ? _openSystemSettings
                      : _requestNotificationPermission,
                ),
                const SizedBox(height: 8),
                _PermissionItem(
                  icon: Icons.battery_saver_rounded,
                  title: '后台保活',
                  description: '建议关闭电池优化，减少后台被清理概率。',
                  statusText: batteryVisual.label,
                  statusColor: batteryVisual.color,
                  statusIcon: batteryVisual.icon,
                  actionLabel: _batteryPermission.isGranted ? '去设置' : '去授权',
                  onAction: _batteryPermission.isGranted
                      ? _openSystemSettings
                      : _requestBatteryPermission,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '设备信息',
              icon: Icons.info_outline_rounded,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7F3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD8D4CC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设备 ID',
                        style: TextStyle(
                          color: Color(0xFF173C36).withValues(alpha: 0.58),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.deviceId,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2F7658),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '可靠性诊断',
              icon: Icons.monitor_heart_outlined,
              trailing: IconButton(
                onPressed: _refreshRelayHealth,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF2F7658),
                  size: 18,
                ),
                tooltip: '刷新队列状态',
              ),
              children: [_RelayHealthSummary(health: _relayHealth)],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowUpdateActionButton() {
    return _updateState.status == AppUpdateStatus.available ||
        _updateState.status == AppUpdateStatus.downloading ||
        _updateState.status == AppUpdateStatus.readyToInstall;
  }

  String _updateActionLabel() {
    if (_isInstallingUpdate) {
      return '安装中...';
    }
    if (_updateState.status == AppUpdateStatus.downloading) {
      return '下载中...';
    }
    if (_updateState.status == AppUpdateStatus.readyToInstall) {
      return '安装更新';
    }
    return '下载并安装';
  }

  String _formatVersionLabel(
    String? version,
    int buildNumber, {
    String emptyLabel = '-',
  }) {
    final normalizedVersion = (version ?? '').trim();
    if (normalizedVersion.isEmpty) {
      return emptyLabel;
    }
    if (buildNumber > 0) {
      return 'v$normalizedVersion ($buildNumber)';
    }
    return 'v$normalizedVersion';
  }

  String _updateStatusText() {
    return switch (_updateState.status) {
      AppUpdateStatus.idle => '尚未检查更新',
      AppUpdateStatus.checking => '正在检查更新...',
      AppUpdateStatus.available => '发现新版本，可以开始下载',
      AppUpdateStatus.upToDate => '当前已经是最新版本',
      AppUpdateStatus.downloading => '正在下载更新包...',
      AppUpdateStatus.readyToInstall => '安装包已就绪，可以继续安装',
      AppUpdateStatus.error =>
        _updateState.message.isEmpty ? '更新失败，请稍后重试' : _updateState.message,
    };
  }

  Color _updateStatusColor() {
    return switch (_updateState.status) {
      AppUpdateStatus.available => const Color(0xFF2F7658),
      AppUpdateStatus.upToDate => const Color(0xFF10B981),
      AppUpdateStatus.downloading => const Color(0xFF2F7658),
      AppUpdateStatus.readyToInstall => const Color(0xFF10B981),
      AppUpdateStatus.error => const Color(0xFFEF4444),
      _ => const Color(0xFF173C36).withValues(alpha: 0.72),
    };
  }

  _PermissionVisual _permissionVisual(PermissionStatus status) {
    if (status.isGranted || status == PermissionStatus.limited) {
      return const _PermissionVisual(
        label: '已开启',
        color: Color(0xFF10B981),
        icon: Icons.check_circle_rounded,
      );
    }
    if (status.isPermanentlyDenied) {
      return const _PermissionVisual(
        label: '已永久拒绝',
        color: Color(0xFFEF4444),
        icon: Icons.cancel_rounded,
      );
    }
    return const _PermissionVisual(
      label: '未开启',
      color: Color(0xFFF59E0B),
      icon: Icons.warning_rounded,
    );
  }

  _PermissionVisual _listenerVisual(bool enabled) {
    if (enabled) {
      return const _PermissionVisual(
        label: '已开启通知监听',
        color: Color(0xFF10B981),
        icon: Icons.check_circle_rounded,
      );
    }
    return const _PermissionVisual(
      label: '未开启通知监听',
      color: Color(0xFFF59E0B),
      icon: Icons.warning_rounded,
    );
  }
}

class _RelayHealthSummary extends StatelessWidget {
  const _RelayHealthSummary({required this.health});

  final NativeRelayHealth? health;

  @override
  Widget build(BuildContext context) {
    final value = health;
    if (value == null) {
      return const Text(
        '正在读取原生队列状态…',
        style: TextStyle(color: Color(0xFF173C36), fontSize: 13),
      );
    }
    final status = value.inFlight == 0 ? '队列已清空' : '有消息等待发送';
    final statusColor = value.inFlight == 0
        ? const Color(0xFF2F7658)
        : const Color(0xFF9A6A2F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              value.inFlight == 0 ? Icons.check_circle_outline : Icons.schedule,
              color: statusColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HealthChip(label: '待发送', value: value.pending),
            _HealthChip(label: '发送中', value: value.sending),
            _HealthChip(label: '待重试', value: value.retrying),
            _HealthChip(label: '已确认', value: value.acked),
          ],
        ),
        if (value.latestErrorCode != null &&
            value.latestErrorCode!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '最近错误：${value.latestErrorCode}',
            style: TextStyle(
              color: const Color(0xFF173C36).withValues(alpha: .58),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE0DDD6)),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(
        color: Color(0xFF173C36),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PermissionVisual {
  const _PermissionVisual({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0DDD6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE9E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF2F7658), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF173C36),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _UpdateSummary extends StatelessWidget {
  const _UpdateSummary({
    required this.currentVersionLabel,
    required this.latestVersionLabel,
    required this.statusText,
    required this.statusColor,
    required this.progress,
    required this.showProgress,
  });

  final String currentVersionLabel;
  final String latestVersionLabel;
  final String statusText;
  final Color statusColor;
  final int progress;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0DDD6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: '当前版本', value: currentVersionLabel),
          const SizedBox(height: 8),
          _InfoRow(label: '最新版本', value: latestVersionLabel),
          const SizedBox(height: 10),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress <= 0 ? 0 : progress / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFE6E2DA),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2F7658),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$progress%',
              style: TextStyle(
                color: const Color(0xFF173C36).withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF173C36).withValues(alpha: 0.58),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF173C36),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.statusText,
    required this.statusColor,
    required this.statusIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String statusText;
  final Color statusColor;
  final IconData statusIcon;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0DDD6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE9E1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2F7658), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF173C36),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xFF173C36).withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                onAction!();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2F7658),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0DDD6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDCE9E1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2F7658), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF173C36),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xFF173C36).withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

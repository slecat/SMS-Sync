import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../platform/channels.dart';
import '../../platform/runtime_support.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with WidgetsBindingObserver {
  PermissionStatus _smsPermission = PermissionStatus.denied;
  PermissionStatus _notificationPermission = PermissionStatus.denied;
  PermissionStatus _batteryPermission = PermissionStatus.denied;
  bool _isNotificationListenerEnabled = false;
  bool _isRefreshing = true;
  bool _isOpeningNotificationListenerSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
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
    }
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
      await platformChannel.invokeMethod<bool>('openNotificationListenerSettings');
    } on PlatformException {
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
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '权限状态、通知监听与设备信息',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
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
                        color: Color(0xFF60A5FA),
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
                      : (_isOpeningNotificationListenerSettings ? '打开中...' : '去开启'),
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
                  actionLabel: _notificationPermission.isGranted ? '去设置' : '去授权',
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
                    color: const Color(0xFF0F141C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '设备 ID',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        widget.deviceId,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA5B4FC),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        color: const Color(0xFF151A25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF60A5FA), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
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
        color: const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF60A5FA), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
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
                foregroundColor: const Color(0xFF60A5FA),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class HomeConfigTab extends StatelessWidget {
  const HomeConfigTab({
    super.key,
    required this.serverStatus,
    required this.groupIdController,
    required this.serverUrlController,
    required this.deviceNameController,
    required this.syncSecretController,
    required this.onSavePreferences,
  });

  final String serverStatus;
  final TextEditingController groupIdController;
  final TextEditingController serverUrlController;
  final TextEditingController deviceNameController;
  final TextEditingController syncSecretController;
  final VoidCallback onSavePreferences;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '首页',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '短信同步配置',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '同步配置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  _SettingItem(
                    icon: Icons.group_rounded,
                    label: '组 ID',
                    hint: '同组设备才能互相通信',
                    controller: groupIdController,
                  ),
                  const SizedBox(height: 16),
                  _SettingItem(
                    icon: Icons.key_rounded,
                    label: '同步密钥',
                    hint: '必填，所有设备需保持一致',
                    controller: syncSecretController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  _SettingItem(
                    icon: Icons.cloud_rounded,
                    label: '服务器地址',
                    hint: 'ws://your-server:3000（可选）',
                    controller: serverUrlController,
                  ),
                  const SizedBox(height: 10),
                  _ServerConnectionStatus(serverStatus: serverStatus),
                  const SizedBox(height: 16),
                  _SettingItem(
                    icon: Icons.phone_android_rounded,
                    label: '设备名称',
                    hint: '手机端',
                    controller: deviceNameController,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onSavePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '保存设置',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerConnectionStatus extends StatelessWidget {
  const _ServerConnectionStatus({required this.serverStatus});

  final String serverStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (serverStatus) {
      'connected' => ('已连接', const Color(0xFF10B981), Icons.cloud_done_rounded),
      'connecting' => ('连接中...', const Color(0xFFF59E0B), Icons.sync_rounded),
      _ => ('未连接', const Color(0xFFEF4444), Icons.cloud_off_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '服务器连接状态：$label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF121212),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}

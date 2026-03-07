import 'package:flutter/material.dart';

class SyncSettingsTab extends StatelessWidget {
  const SyncSettingsTab({
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
    final (statusLabel, statusColor, statusIcon) = switch (serverStatus) {
      'connected' => (
        '服务器已连接',
        const Color(0xFF10B981),
        Icons.cloud_done_rounded,
      ),
      'connecting' => ('服务器连接中', const Color(0xFFF59E0B), Icons.sync_rounded),
      _ => ('服务器未连接', const Color(0xFFEF4444), Icons.cloud_off_rounded),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '配置',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '集中管理分组、密钥、服务器地址',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            _SyncCard(
              statusLabel: statusLabel,
              statusColor: statusColor,
              statusIcon: statusIcon,
              groupIdController: groupIdController,
              serverUrlController: serverUrlController,
              deviceNameController: deviceNameController,
              syncSecretController: syncSecretController,
              onSavePreferences: onSavePreferences,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.groupIdController,
    required this.serverUrlController,
    required this.deviceNameController,
    required this.syncSecretController,
    required this.onSavePreferences,
  });

  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final TextEditingController groupIdController;
  final TextEditingController serverUrlController;
  final TextEditingController deviceNameController;
  final TextEditingController syncSecretController;
  final VoidCallback onSavePreferences;

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
          _SyncInput(
            icon: Icons.group_rounded,
            label: '组 ID',
            hint: '同组设备才能互相通信',
            controller: groupIdController,
          ),
          const SizedBox(height: 10),
          _SyncInput(
            icon: Icons.key_rounded,
            label: '同步密钥',
            hint: '必填，所有设备需保持一致',
            controller: syncSecretController,
            obscureText: true,
          ),
          const SizedBox(height: 10),
          _SyncInput(
            icon: Icons.cloud_rounded,
            label: '服务器地址',
            hint: 'your-server:8004（可选）',
            controller: serverUrlController,
            keyboardType: TextInputType.url,
            prefixText: 'ws://',
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.38)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SyncInput(
            icon: Icons.phone_android_rounded,
            label: '设备名称',
            hint: '用于设备识别',
            controller: deviceNameController,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSavePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '保存设置',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncInput extends StatelessWidget {
  const _SyncInput({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixText,
  });

  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF93C5FD), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: const Color(0xFF0F141C),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF60A5FA),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

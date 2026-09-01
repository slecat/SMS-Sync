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
    final connected = serverStatus == 'connected';
    return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 28), children: [
      const Text('连接', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF173C36), letterSpacing: -.8)),
      const SizedBox(height: 6),
      Text('同组设备使用相同的地址、分组和密钥。', style: TextStyle(color: Colors.black.withValues(alpha: .58))),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0DDD6))), child: Column(children: [
        _Field(label: '分组 ID', icon: Icons.group_outlined, controller: groupIdController, hint: '例如：home'),
        _Field(label: '同步密钥', icon: Icons.key_outlined, controller: syncSecretController, hint: '所有设备保持一致', obscureText: true),
        _Field(label: '服务器地址', icon: Icons.cloud_outlined, controller: serverUrlController, hint: 'your-server:8004', keyboardType: TextInputType.url),
        _Field(label: '设备名称', icon: Icons.phone_android_outlined, controller: deviceNameController, hint: '例如：我的手机'),
        const SizedBox(height: 4),
        Row(children: [Icon(connected ? Icons.check_circle_outline : Icons.pause_circle_outline, color: connected ? const Color(0xFF2F7658) : const Color(0xFF9A6A2F), size: 18), const SizedBox(width: 8), Text(connected ? '服务器已连接' : '等待连接', style: TextStyle(color: connected ? const Color(0xFF2F7658) : const Color(0xFF9A6A2F), fontWeight: FontWeight.w600))]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: onSavePreferences, child: const Text('保存连接'))),
      ])),
    ]));
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.icon, required this.controller, required this.hint, this.obscureText = false, this.keyboardType});
  final String label, hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, size: 19))));
}

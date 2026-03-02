import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '关于',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '权限状态与设备信息',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '权限状态',
              icon: Icons.shield_rounded,
              children: const [
                _PermissionItem(
                  icon: Icons.sms_rounded,
                  title: '短信权限',
                  description: '读取和接收短信',
                ),
                SizedBox(height: 8),
                _PermissionItem(
                  icon: Icons.notifications_rounded,
                  title: '通知权限',
                  description: '显示后台服务通知',
                ),
                SizedBox(height: 8),
                _PermissionItem(
                  icon: Icons.battery_unknown_rounded,
                  title: '电池优化',
                  description: '建议关闭优化以保持后台运行',
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
                        deviceId,
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
  });

  final IconData icon;
  final String title;
  final String description;

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
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 18,
          ),
        ],
      ),
    );
  }
}

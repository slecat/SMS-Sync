import 'package:flutter/material.dart';

const int _deviceOnlineWindowMs = 8000;

class MessagesTab extends StatelessWidget {
  const MessagesTab({
    super.key,
    required this.onlineDevices,
    required this.serverStatus,
    required this.latestSmsFrom,
    required this.latestSmsBody,
    required this.smsCount,
    required this.verificationCodeCount,
    required this.onReadLatestSms,
    required this.onSendTest,
  });

  final Map<String, Map<String, dynamic>> onlineDevices;
  final String serverStatus;
  final String? latestSmsFrom;
  final String? latestSmsBody;
  final int smsCount;
  final int verificationCodeCount;
  final VoidCallback onReadLatestSms;
  final VoidCallback onSendTest;

  @override
  Widget build(BuildContext context) {
    final sortedDevices =
        onlineDevices.values
            .map((device) => Map<String, dynamic>.from(device))
            .toList()
          ..sort((a, b) {
            final aTs = a['timestamp'] as int? ?? 0;
            final bTs = b['timestamp'] as int? ?? 0;
            return bTs.compareTo(aTs);
          });

    final onlineCount = sortedDevices.where(_isOnline).length;
    final runningHealthy = serverStatus == 'connected' || onlineCount > 0;
    final serverLabel = switch (serverStatus) {
      'connected' => '服务器已连接',
      'connecting' => '服务器连接中',
      _ => '服务器未连接',
    };
    final serverColor = switch (serverStatus) {
      'connected' => const Color(0xFF10B981),
      'connecting' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '总览',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '先判断运行状态，再执行核心操作',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111723),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              (runningHealthy
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          runningHealthy
                              ? Icons.verified_rounded
                              : Icons.error_outline_rounded,
                          color: runningHealthy
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              runningHealthy ? '运行正常' : '运行受限',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              serverLabel,
                              style: TextStyle(
                                color: serverColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: '在线设备',
                          value: '$onlineCount',
                          valueColor: const Color(0xFF22D3EE),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: '短信数',
                          value: '$smsCount',
                          valueColor: const Color(0xFFA78BFA),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTile(
                          label: '验证码数',
                          value: '$verificationCodeCount',
                          valueColor: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '快捷操作',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReadLatestSms,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      '读取最新',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onSendTest,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      '发送测试',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: latestSmsFrom != null && latestSmsBody != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestSmsFrom!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          latestSmsBody!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '暂无短信内容，点击“读取最新”从系统短信中拉取。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.56),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              '设备状态 ${sortedDevices.isEmpty ? '' : '(${sortedDevices.length})'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            if (sortedDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '暂无在线设备，确保其他设备在同组且在线。',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.52),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedDevices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (_, index) {
                  return _DeviceStatusCard(device: sortedDevices[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _isOnline(Map<String, dynamic> device) {
    final timestamp = device['timestamp'] as int?;
    if (timestamp == null) {
      return false;
    }
    return DateTime.now().millisecondsSinceEpoch - timestamp <=
        _deviceOnlineWindowMs;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.device});

  final Map<String, dynamic> device;

  @override
  Widget build(BuildContext context) {
    final timestamp = device['timestamp'] as int?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isOnline =
        timestamp != null && nowMs - timestamp <= _deviceOnlineWindowMs;
    final source = device['source'] as String? ?? 'lan';
    final sourceColor = source == 'server'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final statusColor = isOnline
        ? const Color(0xFF22C55E)
        : const Color(0xFFF97316);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline
              ? Colors.white.withValues(alpha: 0.08)
              : statusColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOnline ? Icons.radio_button_checked : Icons.warning_rounded,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? '在线' : '离线',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (device['deviceName'] as String?)?.trim().isNotEmpty == true
                ? device['deviceName'] as String
                : '未知设备',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(timestamp),
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sourceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              source == 'server' ? '服务器' : '局域网',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: sourceColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null) {
      return '刚刚';
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;

    if (diff < 60000) {
      return '刚刚';
    }
    if (diff < 3600000) {
      return '${(diff ~/ 60000)}分钟前';
    }
    if (diff < 86400000) {
      return '${(diff ~/ 3600000)}小时前';
    }
    return '${(diff ~/ 86400000)}天前';
  }
}

import 'package:flutter/material.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key, required this.onlineDevices});

  final Map<String, Map<String, dynamic>> onlineDevices;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在线设备',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '同一组 ID 的在线设备',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            if (onlineDevices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_outlined,
                      color: Colors.white.withValues(alpha: 0.15),
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无在线设备',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '确保其他设备在同一组 ID 并在线',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...onlineDevices.values.map((device) {
                final sources = _resolveSources(device);
                final isDualSource = sources.length > 1;
                final iconColors = isDualSource
                    ? const [Color(0xFFF59E0B), Color(0xFF10B981)]
                    : (sources.first == 'server'
                          ? const [Color(0xFFF59E0B), Color(0xFFEF4444)]
                          : const [Color(0xFF6366F1), Color(0xFF8B5CF6)]);
                final iconData = isDualSource
                    ? Icons.hub_rounded
                    : (sources.first == 'server'
                          ? Icons.cloud_rounded
                          : Icons.devices_rounded);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: iconColors),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(iconData, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (device['deviceName'] as String?)
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? device['deviceName'] as String
                                    : '未知设备',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(device['timestamp'] as int?),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: sources
                                  .map(
                                    (source) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _sourceColor(
                                          source,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _sourceLabel(source),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _sourceColor(source),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '在线',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
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

  List<String> _resolveSources(Map<String, dynamic> device) {
    final raw = device['sources'];
    if (raw is List && raw.isNotEmpty) {
      final normalized = raw
          .map((item) => item.toString() == 'server' ? 'server' : 'lan')
          .toSet()
          .toList();
      normalized.sort(
        (a, b) => _sourcePriority(a).compareTo(_sourcePriority(b)),
      );
      return normalized;
    }
    final source = device['source']?.toString() == 'server' ? 'server' : 'lan';
    return [source];
  }

  int _sourcePriority(String source) {
    if (source == 'server') {
      return 0;
    }
    if (source == 'lan') {
      return 1;
    }
    return 2;
  }

  String _sourceLabel(String source) {
    return source == 'server' ? '服务器' : '局域网';
  }

  Color _sourceColor(String source) {
    return source == 'server'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
  }
}

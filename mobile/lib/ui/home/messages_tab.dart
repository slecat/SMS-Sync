import 'package:flutter/material.dart';

import 'device_presence_status.dart';

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
    final isConnected = serverStatus == 'connected';
    final online = onlineDevices.values.where((device) => isDeviceOnline(device, nowMs: DateTime.now().millisecondsSinceEpoch, timeoutMs: 8000)).length;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const Text('同步', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Color(0xFF173C36), letterSpacing: -0.8)),
          const SizedBox(height: 6),
          Text('短信会先保存在本机，再可靠送达其他设备。', style: TextStyle(color: Colors.black.withValues(alpha: .58), fontSize: 14)),
          const SizedBox(height: 20),
          _HealthCard(connected: isConnected, online: online),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Stat(label: '已接收', value: '$smsCount')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: '验证码', value: '$verificationCodeCount')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(label: '在线设备', value: '$online')),
          ]),
          const SizedBox(height: 22),
          const Text('最近一条', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF173C36))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0DDD6))),
            child: latestSmsBody == null
                ? Text('还没有收到短信', style: TextStyle(color: Colors.black.withValues(alpha: .48)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(latestSmsFrom ?? '未知号码', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF173C36))),
                    const SizedBox(height: 8),
                    Text(latestSmsBody!, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45, color: Color(0xFF30332F))),
                  ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: onReadLatestSms, icon: const Icon(Icons.refresh, size: 18), label: const Text('读取最新'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: onSendTest, icon: const Icon(Icons.send_outlined, size: 18), label: const Text('发送测试'))),
          ]),
          if (onlineDevices.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('设备', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF173C36))),
            const SizedBox(height: 8),
            ...onlineDevices.values.map((device) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(backgroundColor: Color(0xFFDCE9E1), child: Icon(Icons.devices, color: Color(0xFF173C36))),
              title: Text('${device['deviceName'] ?? device['deviceId'] ?? '设备'}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${device['status'] ?? 'online'}'),
            )),
          ],
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.connected, required this.online});
  final bool connected;
  final int online;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF173C36), borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      const Icon(Icons.shield_outlined, color: Color(0xFFE5F0E9), size: 30),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(connected ? '同步正常' : '等待连接', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(connected ? '服务器已连接 · $online 台设备在线' : '消息仍会保存在本机，连接恢复后自动发送', style: const TextStyle(color: Color(0xFFC5D9CE), fontSize: 12)),
      ])),
    ]),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0DDD6))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF173C36))),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: .5))),
    ]),
  );
}

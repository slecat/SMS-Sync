bool isDeviceOnline(
  Map<String, dynamic> device, {
  required int nowMs,
  required int timeoutMs,
}) {
  final status = normalizeDeviceStatus(device['status'] as String?);
  if (status == 'online') {
    return true;
  }
  if (status == 'offline') {
    return false;
  }

  final timestamp = device['timestamp'] as int?;
  if (timestamp == null) {
    return false;
  }
  return nowMs - timestamp <= timeoutMs;
}

String? normalizeDeviceStatus(String? status) {
  if (status == 'online') {
    return 'online';
  }
  if (status == 'offline') {
    return 'offline';
  }
  return null;
}

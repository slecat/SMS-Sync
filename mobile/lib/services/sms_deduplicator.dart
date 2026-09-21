class SmsDeduplicator {
  SmsDeduplicator({required this.minIntervalMs});

  final int minIntervalMs;
  int _lastProcessedSmsId = -1;
  int _lastProcessTime = 0;

  bool shouldProcess({required int smsTimestampMs, int? nowMs}) {
    final currentTime = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final smsId = smsTimestampMs.hashCode;
    final isRecent = (currentTime - _lastProcessTime) > minIntervalMs;
    final isNewId = smsId != _lastProcessedSmsId;

    if (isNewId && isRecent) {
      _lastProcessedSmsId = smsId;
      _lastProcessTime = currentTime;
      return true;
    }

    return false;
  }

  void reset() {
    _lastProcessedSmsId = -1;
    _lastProcessTime = 0;
  }
}

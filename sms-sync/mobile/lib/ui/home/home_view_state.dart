class HomeViewState {
  static final RegExp _verificationCodeDigitsPattern = RegExp(
    r'(?<!\d)\d{4,8}(?!\d)',
  );
  static final RegExp _verificationCodeKeywordPattern = RegExp(
    r'(验证码|校验码|动态码|otp|one[\s-]?time|verification\s*code|security\s*code)',
    caseSensitive: false,
  );

  const HomeViewState({
    required this.deviceId,
    required this.isLoading,
    required this.latestSmsFrom,
    required this.latestSmsBody,
    required this.smsCount,
    required this.verificationCodeCount,
    required this.currentIndex,
    required this.serverStatus,
    required this.onlineDevices,
  });

  factory HomeViewState.initial() {
    return const HomeViewState(
      deviceId: '',
      isLoading: true,
      latestSmsFrom: null,
      latestSmsBody: null,
      smsCount: 0,
      verificationCodeCount: 0,
      currentIndex: 0,
      serverStatus: 'disconnected',
      onlineDevices: {},
    );
  }

  final String deviceId;
  final bool isLoading;
  final String? latestSmsFrom;
  final String? latestSmsBody;
  final int smsCount;
  final int verificationCodeCount;
  final int currentIndex;
  final String serverStatus;
  final Map<String, Map<String, dynamic>> onlineDevices;

  HomeViewState copyWith({
    String? deviceId,
    bool? isLoading,
    String? latestSmsFrom,
    bool clearLatestSmsFrom = false,
    String? latestSmsBody,
    bool clearLatestSmsBody = false,
    int? smsCount,
    int? verificationCodeCount,
    int? currentIndex,
    String? serverStatus,
    Map<String, Map<String, dynamic>>? onlineDevices,
  }) {
    return HomeViewState(
      deviceId: deviceId ?? this.deviceId,
      isLoading: isLoading ?? this.isLoading,
      latestSmsFrom: clearLatestSmsFrom
          ? null
          : latestSmsFrom ?? this.latestSmsFrom,
      latestSmsBody: clearLatestSmsBody
          ? null
          : latestSmsBody ?? this.latestSmsBody,
      smsCount: smsCount ?? this.smsCount,
      verificationCodeCount:
          verificationCodeCount ?? this.verificationCodeCount,
      currentIndex: currentIndex ?? this.currentIndex,
      serverStatus: serverStatus ?? this.serverStatus,
      onlineDevices: onlineDevices ?? this.onlineDevices,
    );
  }

  HomeViewState withSetupData({
    required String deviceId,
    required String groupId,
    required String serverUrl,
    required String deviceName,
    required String syncSecret,
    required String serverStatus,
  }) {
    // Group/server/device/secret remain in input controllers; state keeps
    // only values needed by render/runtime wiring.
    return copyWith(
      deviceId: deviceId,
      isLoading: false,
      serverStatus: serverStatus,
    );
  }

  HomeViewState withServerStatus(String status) {
    return copyWith(serverStatus: status);
  }

  HomeViewState withReceivedSms({required String from, required String body}) {
    final hasVerificationCode = _looksLikeVerificationCode(body);
    return copyWith(
      latestSmsFrom: from,
      latestSmsBody: body,
      smsCount: smsCount + 1,
      verificationCodeCount:
          verificationCodeCount + (hasVerificationCode ? 1 : 0),
    );
  }

  HomeViewState withLatestSms({required String? from, required String? body}) {
    return copyWith(latestSmsFrom: from, latestSmsBody: body);
  }

  HomeViewState withCurrentIndex(int index) {
    return copyWith(currentIndex: index);
  }

  HomeViewState withDevicePresence(
    Map<String, dynamic> device, {
    required String localDeviceId,
  }) {
    final deviceId = device['deviceId'] as String?;
    if (deviceId == null || deviceId == localDeviceId) {
      return this;
    }

    final updated = Map<String, Map<String, dynamic>>.from(onlineDevices);
    final existing = updated[deviceId];
    final normalizedSource = _normalizeSource(device['source'] as String?);
    final incomingTimestamp =
        (device['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    final sourceTimestamps = _extractSourceTimestamps(existing);
    sourceTimestamps[normalizedSource] = incomingTimestamp;
    final sources = _sortSources(sourceTimestamps.keys);
    final latestTimestamp = sourceTimestamps.values.fold<int>(
      0,
      (maxValue, ts) => ts > maxValue ? ts : maxValue,
    );
    final incomingName = (device['deviceName'] as String?)?.trim();
    final existingName = (existing?['deviceName'] as String?)?.trim();
    final resolvedName = (incomingName != null && incomingName.isNotEmpty)
        ? incomingName
        : ((existingName != null && existingName.isNotEmpty)
              ? existingName
              : '未知设备');

    updated[deviceId] = {
      ...?existing,
      ...Map<String, dynamic>.from(device),
      'deviceId': deviceId,
      'deviceName': resolvedName,
      'source': sources.contains('server') ? 'server' : sources.first,
      'sources': sources,
      'sourceTimestamps': sourceTimestamps,
      'timestamp': latestTimestamp,
    };
    return copyWith(onlineDevices: updated);
  }

  HomeViewState withoutStaleDevices({
    required int nowMs,
    required int timeoutMs,
  }) {
    final updated = <String, Map<String, dynamic>>{};
    for (final entry in onlineDevices.entries) {
      final device = Map<String, dynamic>.from(entry.value);
      final sourceTimestamps = _extractSourceTimestamps(device);
      sourceTimestamps.removeWhere((_, ts) => nowMs - ts > timeoutMs);
      if (sourceTimestamps.isEmpty) {
        continue;
      }

      final sources = _sortSources(sourceTimestamps.keys);
      final latestTimestamp = sourceTimestamps.values.fold<int>(
        0,
        (maxValue, ts) => ts > maxValue ? ts : maxValue,
      );
      device['sourceTimestamps'] = sourceTimestamps;
      device['sources'] = sources;
      device['source'] = sources.contains('server') ? 'server' : sources.first;
      device['timestamp'] = latestTimestamp;
      updated[entry.key] = device;
    }
    return copyWith(onlineDevices: updated);
  }

  Map<String, int> _extractSourceTimestamps(Map<String, dynamic>? device) {
    final result = <String, int>{};
    if (device == null) {
      return result;
    }

    final rawSourceTimestamps = device['sourceTimestamps'];
    if (rawSourceTimestamps is Map) {
      for (final entry in rawSourceTimestamps.entries) {
        final key = _normalizeSource(entry.key?.toString());
        final value = entry.value;
        if (value is int) {
          result[key] = value;
          continue;
        }
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) {
            result[key] = parsed;
          }
        }
      }
    }

    if (result.isEmpty) {
      final source = _normalizeSource(device['source'] as String?);
      final timestamp = device['timestamp'] as int?;
      if (timestamp != null) {
        result[source] = timestamp;
      }
    }

    return result;
  }

  List<String> _sortSources(Iterable<String> sources) {
    final normalized = {
      for (final source in sources) _normalizeSource(source): true,
    }.keys.toList();
    normalized.sort((a, b) => _sourcePriority(a).compareTo(_sourcePriority(b)));
    return normalized;
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

  String _normalizeSource(String? source) {
    return source == 'server' ? 'server' : 'lan';
  }

  bool _looksLikeVerificationCode(String body) {
    final normalized = body.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return _verificationCodeKeywordPattern.hasMatch(normalized) &&
        _verificationCodeDigitsPattern.hasMatch(normalized);
  }
}

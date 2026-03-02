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
    updated[deviceId] = Map<String, dynamic>.from(device);
    return copyWith(onlineDevices: updated);
  }

  HomeViewState withoutStaleDevices({
    required int nowMs,
    required int timeoutMs,
  }) {
    final updated = Map<String, Map<String, dynamic>>.from(onlineDevices);
    updated.removeWhere((_, device) {
      final ts = device['timestamp'] as int?;
      if (ts == null) {
        return true;
      }
      return nowMs - ts > timeoutMs;
    });
    return copyWith(onlineDevices: updated);
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

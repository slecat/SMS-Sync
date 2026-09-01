import 'package:flutter/services.dart';

import 'channels.dart';

class NativeRelayHealth {
  const NativeRelayHealth({
    required this.pending,
    required this.sending,
    required this.retrying,
    required this.acked,
    this.oldestPendingAt,
    this.latestAckAt,
    this.latestErrorCode,
  });

  final int pending;
  final int sending;
  final int retrying;
  final int acked;
  final int? oldestPendingAt;
  final int? latestAckAt;
  final String? latestErrorCode;

  int get inFlight => pending + sending + retrying;

  factory NativeRelayHealth.fromMap(Map<Object?, Object?>? raw) {
    int readInt(Object? value) =>
        value is int ? value : int.tryParse('$value') ?? 0;
    int? readOptionalInt(Object? value) =>
        value == null ? null : readInt(value);
    final map = raw ?? const <Object?, Object?>{};
    return NativeRelayHealth(
      pending: readInt(map['pending']),
      sending: readInt(map['sending']),
      retrying: readInt(map['retrying']),
      acked: readInt(map['acked']),
      oldestPendingAt: readOptionalInt(map['oldestPendingAt']),
      latestAckAt: readOptionalInt(map['latestAckAt']),
      latestErrorCode: map['latestErrorCode']?.toString(),
    );
  }
}

class NativeRelayChannel {
  const NativeRelayChannel({MethodChannel channel = platformChannel})
    : _channel = channel;

  final MethodChannel _channel;

  Future<NativeRelayHealth> readHealth() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getRelayHealth',
    );
    return NativeRelayHealth.fromMap(raw);
  }

  Future<void> ensureRunning() async {
    await _channel.invokeMethod<bool>('ensureKeepAliveActive');
  }
}

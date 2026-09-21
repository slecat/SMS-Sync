import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/sms_deduplicator.dart';

void main() {
  group('SmsDeduplicator', () {
    test('first sms should be processed', () {
      final deduplicator = SmsDeduplicator(minIntervalMs: 2000);

      final result = deduplicator.shouldProcess(
        smsTimestampMs: 1000,
        nowMs: 5000,
      );

      expect(result, isTrue);
    });

    test('same sms timestamp should be skipped', () {
      final deduplicator = SmsDeduplicator(minIntervalMs: 2000);

      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1000, nowMs: 5000),
        isTrue,
      );
      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1000, nowMs: 8000),
        isFalse,
      );
    });

    test('different sms within interval should be skipped', () {
      final deduplicator = SmsDeduplicator(minIntervalMs: 2000);

      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1000, nowMs: 5000),
        isTrue,
      );
      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1001, nowMs: 6500),
        isFalse,
      );
    });

    test('different sms after interval should be processed', () {
      final deduplicator = SmsDeduplicator(minIntervalMs: 2000);

      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1000, nowMs: 5000),
        isTrue,
      );
      expect(
        deduplicator.shouldProcess(smsTimestampMs: 1001, nowMs: 8001),
        isTrue,
      );
    });
  });
}

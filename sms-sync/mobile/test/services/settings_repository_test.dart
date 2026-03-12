import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms_sync_mobile/services/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = SettingsRepository();
    });

    test(
      'pending native sms queue can be restored after a deferred flush',
      () async {
        const pendingQueue = [
          {
            'from': '1068',
            'body': 'code: 123456',
            'timestamp': 1234567890,
            'source': 'sms-receiver',
          },
        ];

        SharedPreferences.setMockInitialValues({
          SettingsRepository.pendingNativeSmsQueueKey: jsonEncode(pendingQueue),
        });
        repository = SettingsRepository();

        final taken = await repository.takePendingNativeSmsQueue();
        expect(taken, hasLength(1));

        await repository.savePendingNativeSmsQueue(taken);
        final restored = await repository.takePendingNativeSmsQueue();
        expect(restored, hasLength(1));
        expect(restored.first['from'], '1068');
        expect(restored.first['body'], 'code: 123456');
      },
    );
  });
}

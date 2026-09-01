import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/app/service_registry.dart';

void main() {
  test('createDefault uses the software download service base URL', () {
    final services = AppServices.createDefault();

    expect(
      services.appUpdateService.apiBaseUrl,
      'http://111.228.32.128:8002',
    );
  });
}

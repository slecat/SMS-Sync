import 'package:flutter_test/flutter_test.dart';
import 'package:sms_sync_mobile/services/verification_code_detector.dart';

void main() {
  group('isVerificationCodeMessage', () {
    test('returns true for common verification code messages', () {
      expect(isVerificationCodeMessage('【应用】您的验证码是 123456，5分钟内有效。'), isTrue);
      expect(isVerificationCodeMessage('Your code is 246810.'), isTrue);
    });

    test('returns false for plain numeric logistics or order messages', () {
      expect(isVerificationCodeMessage('快递单号 123456 已发出，请注意查收。'), isFalse);
      expect(isVerificationCodeMessage('订单金额 1234 元，感谢购买。'), isFalse);
    });

    test('returns false for empty text', () {
      expect(isVerificationCodeMessage(''), isFalse);
      expect(isVerificationCodeMessage('   '), isFalse);
    });
  });
}

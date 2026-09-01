final RegExp _verificationCodeDigitsPattern = RegExp(r'(?<!\d)\d{4,8}(?!\d)');
final RegExp _verificationCodeKeywordPattern = RegExp(
  r'(验证码|校验码|动态码|otp|one[\s-]?time|verification\s*code|security\s*code|\bcode\b)',
  caseSensitive: false,
);

bool isVerificationCodeMessage(String body) {
  final normalized = body.trim();
  if (normalized.isEmpty) {
    return false;
  }

  return _verificationCodeKeywordPattern.hasMatch(normalized) &&
      _verificationCodeDigitsPattern.hasMatch(normalized);
}

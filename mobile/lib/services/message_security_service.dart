import 'dart:convert';

import 'package:crypto/crypto.dart';

class MessageSecurityService {
  const MessageSecurityService();

  static const String signatureKey = '_sig';
  static const String signatureVersionKey = '_sig_v';
  static const int signatureVersion = 1;

  Map<String, dynamic> signPayload(
    Map<String, dynamic> payload, {
    required String secret,
  }) {
    if (secret.isEmpty) {
      return Map<String, dynamic>.from(payload);
    }

    final normalized = _canonicalJson(payload);
    final signature = _computeSignature(normalized, secret);

    final signed = Map<String, dynamic>.from(payload);
    signed[signatureVersionKey] = signatureVersion;
    signed[signatureKey] = signature;
    return signed;
  }

  bool verifyPayload(
    Map<String, dynamic> payload, {
    required String secret,
  }) {
    if (secret.isEmpty) {
      return true;
    }

    final signature = payload[signatureKey];
    final version = payload[signatureVersionKey];

    if (signature is! String || signature.isEmpty || version != signatureVersion) {
      return false;
    }

    final unsigned = Map<String, dynamic>.from(payload)
      ..remove(signatureKey)
      ..remove(signatureVersionKey);

    final normalized = _canonicalJson(unsigned);
    final expected = _computeSignature(normalized, secret);
    return _constantTimeEquals(signature, expected);
  }

  String _computeSignature(String normalizedPayload, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(normalizedPayload)).toString();
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      final canonical = <String, Object?>{};
      for (final key in keys) {
        canonical[key] = _canonicalizeValue(value[key]);
      }
      return jsonEncode(canonical);
    }
    return jsonEncode(_canonicalizeValue(value));
  }

  Object? _canonicalizeValue(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((e) => e.toString()).toList()..sort();
      final canonical = <String, Object?>{};
      for (final key in keys) {
        canonical[key] = _canonicalizeValue(value[key]);
      }
      return canonical;
    }
    if (value is List) {
      return value.map(_canonicalizeValue).toList();
    }
    return value;
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();
  static const bool _enableTrace = false;

  static void debug(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(message);
  }

  static void trace(String message) {
    if (!kDebugMode || !_enableTrace) {
      return;
    }
    debugPrint(message);
  }
}

import 'package:flutter/material.dart';

enum HomeSnackBarTone { info, warning, error }

class HomeSnackBar {
  const HomeSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    HomeSnackBarTone tone = HomeSnackBarTone.info,
  }) {
    final backgroundColor = switch (tone) {
      HomeSnackBarTone.error => const Color(0xFFEF4444),
      HomeSnackBarTone.warning => const Color(0xFFF59E0B),
      HomeSnackBarTone.info => const Color(0xFF6366F1),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

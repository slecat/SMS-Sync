import 'package:flutter/material.dart';

import '../ui/home_page.dart';

class SmsSyncApp extends StatelessWidget {
  const SmsSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '短信同步',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F1EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF173C36),
          brightness: Brightness.light,
          surface: const Color(0xFFF4F1EB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F1EB),
          foregroundColor: Color(0xFF173C36),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD8D4CC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD8D4CC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF173C36), width: 1.5),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

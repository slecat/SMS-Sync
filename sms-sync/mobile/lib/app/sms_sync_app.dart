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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

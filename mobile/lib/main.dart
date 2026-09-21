import 'package:flutter/material.dart';

import 'app/sms_sync_app.dart';
import 'background/background_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const SmsSyncApp());
}

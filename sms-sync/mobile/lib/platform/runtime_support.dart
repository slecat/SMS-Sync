import 'dart:io';

import 'package:flutter/foundation.dart';

bool get supportsBackgroundService =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get supportsAndroidSmsSyncRuntime => !kIsWeb && Platform.isAndroid;

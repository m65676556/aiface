import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    SharedPreferencesStorePlatform.instance = SharedPreferencesPlugin();
  }
  runApp(
    const ProviderScope(
      child: AIFaceApp(),
    ),
  );
}

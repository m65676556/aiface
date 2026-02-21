import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/onboarding_screen.dart';

class AIFaceApp extends ConsumerWidget {
  const AIFaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'AIFace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _EntryPoint(),
    );
  }
}

class _EntryPoint extends StatefulWidget {
  const _EntryPoint();

  @override
  State<_EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<_EntryPoint> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      String? value;
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        value = prefs.getString('onboarding_complete');
      } else {
        const storage = FlutterSecureStorage();
        value = await storage.read(key: 'onboarding_complete');
      }
      setState(() => _onboardingComplete = value == 'true');
    } catch (e) {
      setState(() => _onboardingComplete = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_onboardingComplete!) {
      return const ChatScreen();
    }

    return const OnboardingScreen();
  }
}

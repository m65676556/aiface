import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../face/pixel_face_widget.dart';
import '../face/expression.dart';
import '../chat/chat_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'openrouter';

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      final configNotifier = ref.read(llmConfigProvider.notifier);
      if (_selectedProvider == 'openai') {
        await configNotifier.setOpenAiKey(key);
        await configNotifier.setModel('gpt-4o-mini');
      } else if (_selectedProvider == 'anthropic') {
        await configNotifier.setAnthropicKey(key);
        await configNotifier.setModel('claude-haiku-4-5-20251001');
      } else {
        await configNotifier.setOpenRouterKey(key);
        await configNotifier.setModel('google/gemini-2.0-flash-exp:free');
      }
    }

    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onboarding_complete', 'true');
      } else {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'onboarding_complete', value: 'true');
      }
    } catch (e) {
      debugPrint('Onboarding save error: $e');
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  // Page 1: Welcome
                  _buildPage(
                    expression: Expression.happy,
                    title: 'Welcome to AIFace!',
                    subtitle: 'Your pixel art AI assistant with personality.',
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Talk to me through voice or text.\nI remember our conversations!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  // Page 2: API Key
                  _buildPage(
                    expression: Expression.thinking,
                    title: 'Set Up Your AI',
                    subtitle: 'Enter an API key to get started.',
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _providerChip('OpenRouter', 'openrouter'),
                            _providerChip('OpenAI', 'openai'),
                            _providerChip('Anthropic', 'anthropic'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: TextField(
                            controller: _apiKeyController,
                            style: TextStyle(color: AppTheme.textColor),
                            decoration: InputDecoration(
                              hintText: _selectedProvider == 'openai'
                                  ? 'sk-...'
                                  : _selectedProvider == 'anthropic'
                                      ? 'sk-ant-...'
                                      : 'sk-or-...',
                              prefixIcon: const Icon(Icons.key),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You can change this later in settings.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Page 3: Permissions
                  _buildPage(
                    expression: Expression.excited,
                    title: "You're All Set!",
                    subtitle: 'Optional: grant permissions for the full experience.',
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _permissionTile(Icons.mic, 'Microphone', 'For voice chat'),
                        _permissionTile(Icons.camera_alt, 'Camera', 'To show me things'),
                        _permissionTile(Icons.record_voice_over, 'Speech', 'For voice recognition'),
                        const SizedBox(height: 8),
                        Text(
                          'Permissions will be requested when needed.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Container(
                width: _currentPage == i ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentPage == i ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),

            const SizedBox(height: 24),

            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _currentPage < 2 ? _nextPage : _finish,
                  child: Text(
                    _currentPage < 2 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            if (_currentPage > 0)
              TextButton(
                onPressed: _finish,
                child: Text('Skip', style: TextStyle(color: AppTheme.textSecondary)),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required Expression expression,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelFaceWidget(expression: expression, size: 160),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          child,
        ],
      ),
    );
  }

  Widget _providerChip(String label, String value) {
    final selected = _selectedProvider == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _permissionTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

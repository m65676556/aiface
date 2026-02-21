import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../face/expression.dart';

class VoiceButton extends ConsumerStatefulWidget {
  final void Function(String text) onResult;
  final bool enabled;

  const VoiceButton({
    super.key,
    required this.onResult,
    this.enabled = true,
  });

  @override
  ConsumerState<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<VoiceButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startListening() async {
    if (!widget.enabled) return;
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);
    ref.read(expressionProvider.notifier).state = Expression.listening;

    final voice = ref.read(voiceServiceProvider);
    await voice.startListening((text) {
      _stopListening();
      if (text.isNotEmpty) {
        widget.onResult(text);
      }
    });
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _pulseController.stop();
    _pulseController.reset();
    ref.read(expressionProvider.notifier).state = Expression.neutral;
    ref.read(voiceServiceProvider).stopListening();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      onTap: () {
        if (_isListening) {
          _stopListening();
        } else {
          _startListening();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? AppTheme.accentColor : AppTheme.primaryColor,
                boxShadow: [
                  if (_isListening)
                    BoxShadow(
                      color: AppTheme.accentColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 32,
              ),
            ),
          );
        },
      ),
    );
  }
}

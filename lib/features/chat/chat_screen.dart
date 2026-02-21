import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../providers/providers.dart';
import '../face/pixel_face_widget.dart';
import '../french/word_card_screen.dart';
import '../dating/dating_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'chat_bubble.dart';
import 'voice_button.dart';
import 'camera_preview.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showTextInput = true;

  @override
  void initState() {
    super.initState();
    // Initialize voice service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();

    final llm = ref.read(llmServiceProvider);
    if (llm == null) {
      AppUtils.showSnackBar(context, 'Please configure API key in settings', isError: true);
      return;
    }

    ref.read(isSendingProvider.notifier).state = true;

    String? imageBase64;
    if (ref.read(cameraEnabledProvider)) {
      final camera = ref.read(cameraServiceProvider);
      imageBase64 = await camera.captureBase64();
    }

    await ref.read(chatControllerProvider).sendMessage(text, imageBase64: imageBase64);
    ref.read(isSendingProvider.notifier).state = false;
    _scrollToBottom();
  }

  Future<void> _onVoiceResult(String text) async {
    if (text.isEmpty) return;

    final llm = ref.read(llmServiceProvider);
    if (llm == null) {
      AppUtils.showSnackBar(context, 'Please configure API key in settings', isError: true);
      return;
    }

    ref.read(isSendingProvider.notifier).state = true;

    String? imageBase64;
    if (ref.read(cameraEnabledProvider)) {
      final camera = ref.read(cameraServiceProvider);
      imageBase64 = await camera.captureBase64();
    }

    await ref.read(chatControllerProvider).sendMessage(text, imageBase64: imageBase64);
    ref.read(isSendingProvider.notifier).state = false;
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final expression = ref.watch(expressionProvider);
    final isSending = ref.watch(isSendingProvider);
    final cameraEnabled = ref.watch(cameraEnabledProvider);
    final isLearningMode = ref.watch(learningModeProvider);

    // Auto-scroll when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('AIFace'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite,
                color: Colors.pink.withOpacity(0.8)),
            tooltip: '交友档案',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DatingProfileScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.style,
              color: isLearningMode ? Colors.blue : AppTheme.textSecondary,
            ),
            tooltip: '单词卡片',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WordCardScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.language,
              color: isLearningMode ? Colors.blue : AppTheme.textSecondary,
            ),
            tooltip: isLearningMode ? '退出法语模式' : '开启法语学习',
            onPressed: () =>
                ref.read(learningModeProvider.notifier).state = !isLearningMode,
          ),
          IconButton(
            icon: Icon(
              cameraEnabled ? Icons.videocam : Icons.videocam_off,
              color: cameraEnabled ? AppTheme.accentColor : AppTheme.textSecondary,
            ),
            onPressed: () async {
              final newState = !cameraEnabled;
              ref.read(cameraEnabledProvider.notifier).state = newState;
              if (newState) {
                await ref.read(cameraServiceProvider).initialize();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => ref.read(chatControllerProvider).newConversation(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // French learning mode banner
          if (isLearningMode)
            Container(
              width: double.infinity,
              color: Colors.blue.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Text(
                '🇫🇷 法语学习模式 — 输入法语，AI 帮你纠错',
                style: TextStyle(color: Colors.blue, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          // Pixel face
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PixelFaceWidget(
                  expression: expression,
                  size: 180,
                ),
                // Camera preview overlay
                if (cameraEnabled)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CameraPreviewWidget(size: 60),
                  ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Tap the mic button or type to start chatting!',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      if (msg.role == 'system') return const SizedBox.shrink();
                      return ChatBubble(
                        message: AppUtils.removeExpressionTags(msg.content),
                        isUser: msg.role == 'user',
                        hasImage: msg.imageBase64 != null,
                      );
                    },
                  ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  VoiceButton(
                    onResult: _onVoiceResult,
                    enabled: !isSending,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendText(),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: isSending ? AppTheme.textSecondary : AppTheme.primaryColor,
                    ),
                    onPressed: isSending ? null : _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

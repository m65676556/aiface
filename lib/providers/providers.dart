import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database.dart';
import '../data/models/llm_config.dart';
import '../data/models/message.dart' as app;
import '../features/face/expression.dart';
import '../services/llm/llm_factory.dart';
import '../services/llm/llm_service.dart';
import '../services/voice/voice_service.dart';
import '../services/camera/camera_service.dart';
import '../services/memory/memory_service.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _secureStorage = FlutterSecureStorage();

// Web-compatible storage helpers
Future<String?> _readKey(String key) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
  try {
    return await _secureStorage.read(key: key);
  } catch (e) {
    debugPrint('Storage read error: $e');
    return null;
  }
}

Future<void> _writeKey(String key, String value) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    return;
  }
  try {
    await _secureStorage.write(key: key, value: value);
  } catch (e) {
    debugPrint('Storage write error: $e');
  }
}

// Database
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// LLM Config
final llmConfigProvider =
    StateNotifierProvider<LlmConfigNotifier, LlmConfig>((ref) {
  return LlmConfigNotifier();
});

class LlmConfigNotifier extends StateNotifier<LlmConfig> {
  LlmConfigNotifier() : super(const LlmConfig()) {
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      final openaiKey = await _readKey('openai_api_key');
      final anthropicKey = await _readKey('anthropic_api_key');
      final openrouterKey = await _readKey('openrouter_api_key');
      final modelId = await _readKey('selected_model');
      state = LlmConfig(
        openaiApiKey: openaiKey,
        anthropicApiKey: anthropicKey,
        openrouterApiKey: openrouterKey,
        selectedModelId: modelId ?? 'gpt-4o-mini',
      );
    } catch (e) {
      debugPrint('Storage load error: $e');
    }
  }

  Future<void> setOpenAiKey(String key) async {
    await _writeKey('openai_api_key', key);
    state = state.copyWith(openaiApiKey: key);
  }

  Future<void> setAnthropicKey(String key) async {
    await _writeKey('anthropic_api_key', key);
    state = state.copyWith(anthropicApiKey: key);
  }

  Future<void> setOpenRouterKey(String key) async {
    await _writeKey('openrouter_api_key', key);
    state = state.copyWith(openrouterApiKey: key);
  }

  Future<void> setModel(String modelId) async {
    await _writeKey('selected_model', modelId);
    state = state.copyWith(selectedModelId: modelId);
  }
}

// LLM Service
final llmServiceProvider = Provider<LlmService?>((ref) {
  final config = ref.watch(llmConfigProvider);
  try {
    return LlmFactory.create(config);
  } catch (_) {
    return null;
  }
});

// Voice Service
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Camera Service
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Memory Service
final memoryServiceProvider = Provider<MemoryService>((ref) {
  return MemoryService();
});

// Expression state
final expressionProvider = StateProvider<Expression>((ref) => Expression.neutral);

// Current conversation ID
final currentConversationIdProvider = StateProvider<String?>((ref) => null);

// Messages for current conversation
final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<app.Message>>((ref) {
  return MessagesNotifier(ref);
});

class MessagesNotifier extends StateNotifier<List<app.Message>> {
  final Ref _ref;

  MessagesNotifier(this._ref) : super([]);

  Future<void> loadMessages(String conversationId) async {
    final db = _ref.read(databaseProvider);
    final dbMessages = await db.getMessages(conversationId);
    state = dbMessages
        .map((m) => app.Message(
              id: m.id,
              conversationId: conversationId,
              role: m.role,
              content: m.content,
              imageBase64: m.imageBase64,
              createdAt: m.createdAt,
            ))
        .toList();
  }

  Future<void> addMessage(app.Message message) async {
    state = [...state, message];
    final db = _ref.read(databaseProvider);
    await db.insertMessage(MessagesCompanion.insert(
      id: message.id,
      conversationId: message.conversationId,
      role: message.role,
      content: message.content,
      imageBase64: Value(message.imageBase64),
      createdAt: Value(message.createdAt),
    ));
    await db.updateConversationTimestamp(message.conversationId);
  }

  void addPlaceholder(app.Message message) {
    state = [...state, message];
  }

  void updateLastAssistantMessage(String content) {
    if (state.isEmpty) return;
    final last = state.last;
    if (last.role != 'assistant') return;
    state = [
      ...state.sublist(0, state.length - 1),
      last.copyWith(content: content),
    ];
  }

  Future<void> finalizeLastAssistantMessage() async {
    if (state.isEmpty) return;
    final last = state.last;
    if (last.role != 'assistant') return;
    final db = _ref.read(databaseProvider);
    await db.insertMessage(MessagesCompanion.insert(
      id: last.id,
      conversationId: last.conversationId,
      role: last.role,
      content: last.content,
      imageBase64: Value(last.imageBase64),
      createdAt: Value(last.createdAt),
    ));
  }

  List<app.Message> get messages => state;

  void clear() {
    state = [];
  }
}

// Chat controller - orchestrates the full conversation loop
final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref);
});

class ChatController {
  final Ref _ref;

  ChatController(this._ref);

  Future<String> ensureConversation() async {
    var convId = _ref.read(currentConversationIdProvider);
    if (convId == null) {
      convId = _uuid.v4();
      final db = _ref.read(databaseProvider);
      await db.insertConversation(ConversationsCompanion.insert(
        id: convId,
      ));
      _ref.read(currentConversationIdProvider.notifier).state = convId;
    }
    return convId;
  }

  Future<void> sendMessage(String text, {String? imageBase64}) async {
    final llm = _ref.read(llmServiceProvider);
    if (llm == null) return;

    final convId = await ensureConversation();
    final messagesNotifier = _ref.read(messagesProvider.notifier);

    // Add user message
    final userMsg = app.Message(
      id: _uuid.v4(),
      conversationId: convId,
      role: 'user',
      content: text,
      imageBase64: imageBase64,
      createdAt: DateTime.now(),
    );
    await messagesNotifier.addMessage(userMsg);

    // Set thinking expression
    _ref.read(expressionProvider.notifier).state = Expression.thinking;

    // Build memory context
    final memoryService = _ref.read(memoryServiceProvider);
    final db = _ref.read(databaseProvider);
    final memories = await db.getRecentMemories(AppConstants.maxMemoriesInContext);
    final memoryContext = memoryService.buildMemoryContext(
      memories.map((m) => m.content).toList(),
    );
    final isLearningMode = _ref.read(learningModeProvider);
    final basePrompt = isLearningMode
        ? AppConstants.frenchLearningSystemPrompt
        : AppConstants.defaultSystemPrompt;
    final systemPrompt = basePrompt + memoryContext;

    // Create placeholder assistant message
    final assistantMsg = app.Message(
      id: _uuid.v4(),
      conversationId: convId,
      role: 'assistant',
      content: '',
      createdAt: DateTime.now(),
    );
    // Add empty message to state (not DB yet)
    messagesNotifier.addPlaceholder(assistantMsg);

    // Stream response
    String fullResponse = '';
    try {
      await for (final chunk in llm.streamChat(
        messagesNotifier.messages
            .where((m) => m.role != 'assistant' || m.content.isNotEmpty)
            .toList(),
        systemPrompt: systemPrompt,
      )) {
        fullResponse += chunk;
        messagesNotifier.updateLastAssistantMessage(fullResponse);

        // Update expression from tags
        final expr = AppUtils.parseExpression(fullResponse);
        _ref.read(expressionProvider.notifier).state = expressionFromString(expr);
      }
    } catch (e) {
      // Fallback to non-streaming
      try {
        fullResponse = await llm.chat(
          messagesNotifier.messages
              .where((m) => m.id != assistantMsg.id)
              .toList(),
          systemPrompt: systemPrompt,
        );
        messagesNotifier.updateLastAssistantMessage(fullResponse);
        final expr = AppUtils.parseExpression(fullResponse);
        _ref.read(expressionProvider.notifier).state = expressionFromString(expr);
      } catch (e) {
        messagesNotifier.updateLastAssistantMessage('Sorry, I encountered an error: $e');
        _ref.read(expressionProvider.notifier).state = Expression.sad;
      }
    }

    // Save final message to DB
    await messagesNotifier.finalizeLastAssistantMessage();

    // Speak the response (without expression tags)
    final cleanText = AppUtils.removeExpressionTags(fullResponse);
    if (cleanText.isNotEmpty) {
      _ref.read(expressionProvider.notifier).state = Expression.talking;
      final voice = _ref.read(voiceServiceProvider);
      await voice.speak(cleanText);
    }

    // Check if we should extract memories
    final msgCount = messagesNotifier.messages.length;
    if (msgCount > 0 && msgCount % AppConstants.memoryExtractionInterval == 0) {
      _extractMemories(convId);
    }
  }

  Future<void> _extractMemories(String convId) async {
    final llm = _ref.read(llmServiceProvider);
    if (llm == null) return;

    final memService = _ref.read(memoryServiceProvider);
    final recentMessages = _ref.read(messagesProvider.notifier).messages;
    final extracted = await memService.extractMemories(
      llm,
      recentMessages.length > 10
          ? recentMessages.sublist(recentMessages.length - 10)
          : recentMessages,
    );

    final db = _ref.read(databaseProvider);
    for (final mem in extracted) {
      await db.insertMemory(MemoriesCompanion.insert(
        id: _uuid.v4(),
        content: mem['content']!,
        category: Value(mem['category'] ?? 'fact'),
      ));
    }
  }

  Future<void> newConversation() async {
    _ref.read(currentConversationIdProvider.notifier).state = null;
    _ref.read(messagesProvider.notifier).clear();
    _ref.read(expressionProvider.notifier).state = Expression.neutral;
  }

  Future<void> loadConversation(String conversationId) async {
    _ref.read(currentConversationIdProvider.notifier).state = conversationId;
    await _ref.read(messagesProvider.notifier).loadMessages(conversationId);
  }
}

// Conversations list
final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final db = ref.read(databaseProvider);
  return db.getAllConversations();
});

// Is sending message
final isSendingProvider = StateProvider<bool>((ref) => false);

// Camera enabled
final cameraEnabledProvider = StateProvider<bool>((ref) => false);

// French learning mode
final learningModeProvider = StateProvider<bool>((ref) => false);

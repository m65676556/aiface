import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/llm_config.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _openaiController = TextEditingController();
  final _anthropicController = TextEditingController();
  final _openrouterController = TextEditingController();
  final _customModelController = TextEditingController();
  bool _obscureOpenai = true;
  bool _obscureAnthropic = true;
  bool _obscureOpenRouter = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(llmConfigProvider);
      _openaiController.text = config.openaiApiKey ?? '';
      _anthropicController.text = config.anthropicApiKey ?? '';
      _openrouterController.text = config.openrouterApiKey ?? '';
      _customModelController.text = config.selectedModelId;
    });
  }

  @override
  void dispose() {
    _openaiController.dispose();
    _anthropicController.dispose();
    _customModelController.dispose();
    _openrouterController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final llm = ref.read(llmServiceProvider);
    if (llm == null) {
      AppUtils.showSnackBar(context, 'No API key configured for selected model', isError: true);
      setState(() => _testing = false);
      return;
    }

    try {
      final success = await llm.testConnection();
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          success ? 'Connection successful!' : 'Connection failed — check API key',
          isError: !success,
        );
        setState(() => _testing = false);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(llmConfigProvider);
    final configNotifier = ref.read(llmConfigProvider.notifier);

    // Ensure the selected model ID is always valid
    final validIds = LlmModel.availableModels.map((m) => m.id).toSet();
    final safeModelId = validIds.contains(config.selectedModelId)
        ? config.selectedModelId
        : LlmModel.availableModels.first.id;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Model Selection
          Text('Model', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: safeModelId,
              isExpanded: true,
              dropdownColor: AppTheme.surfaceColor,
              underline: const SizedBox(),
              style: TextStyle(color: AppTheme.textColor),
              items: LlmModel.availableModels
                  .map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.displayName} (${m.provider.name})'),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) configNotifier.setModel(value);
              },
            ),
          ),

          const SizedBox(height: 12),
          Text('Custom Model ID (override)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _customModelController,
            style: TextStyle(color: AppTheme.textColor),
            decoration: InputDecoration(
              hintText: 'e.g. mistralai/mistral-7b-instruct:free',
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  final id = _customModelController.text.trim();
                  if (id.isNotEmpty) configNotifier.setModel(id);
                },
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) configNotifier.setModel(v.trim());
            },
          ),

          const SizedBox(height: 24),

          // OpenAI API Key
          Text('OpenAI API Key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _openaiController,
            obscureText: _obscureOpenai,
            style: TextStyle(color: AppTheme.textColor),
            decoration: InputDecoration(
              hintText: 'sk-...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureOpenai ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureOpenai = !_obscureOpenai),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => configNotifier.setOpenAiKey(_openaiController.text.trim()),
                  ),
                ],
              ),
            ),
            onSubmitted: (v) => configNotifier.setOpenAiKey(v.trim()),
          ),

          const SizedBox(height: 24),

          // Anthropic API Key
          Text('Anthropic API Key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _anthropicController,
            obscureText: _obscureAnthropic,
            style: TextStyle(color: AppTheme.textColor),
            decoration: InputDecoration(
              hintText: 'sk-ant-...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureAnthropic ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureAnthropic = !_obscureAnthropic),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => configNotifier.setAnthropicKey(_anthropicController.text.trim()),
                  ),
                ],
              ),
            ),
            onSubmitted: (v) => configNotifier.setAnthropicKey(v.trim()),
          ),

          const SizedBox(height: 24),

          // OpenRouter API Key
          Text('OpenRouter API Key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _openrouterController,
            obscureText: _obscureOpenRouter,
            style: TextStyle(color: AppTheme.textColor),
            decoration: InputDecoration(
              hintText: 'sk-or-...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscureOpenRouter ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureOpenRouter = !_obscureOpenRouter),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => configNotifier.setOpenRouterKey(_openrouterController.text.trim()),
                  ),
                ],
              ),
            ),
            onSubmitted: (v) => configNotifier.setOpenRouterKey(v.trim()),
          ),

          const SizedBox(height: 32),

          // Test Connection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
              onPressed: _testing ? null : _testConnection,
            ),
          ),

          const SizedBox(height: 32),

          // Conversations management
          Text('Conversations', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Consumer(builder: (context, ref, _) {
            final conversations = ref.watch(conversationsProvider);
            return conversations.when(
              data: (convs) {
                if (convs.isEmpty) {
                  return Text('No conversations yet', style: TextStyle(color: AppTheme.textSecondary));
                }
                return Column(
                  children: convs.map((c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.title, style: TextStyle(color: AppTheme.textColor)),
                    subtitle: Text(
                      '${c.updatedAt.month}/${c.updatedAt.day}/${c.updatedAt.year}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        await db.deleteConversation(c.id);
                        ref.invalidate(conversationsProvider);
                      },
                    ),
                    onTap: () {
                      ref.read(chatControllerProvider).loadConversation(c.id);
                      Navigator.pop(context);
                    },
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('No conversations', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }),

          const SizedBox(height: 32),

          // Memories
          Text('Memories', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          FutureBuilder(
            future: ref.read(databaseProvider).getAllMemories().catchError((_) => []),
            builder: (context, snapshot) {
              if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                return Text('No memories yet', style: TextStyle(color: AppTheme.textSecondary));
              }
              final memories = snapshot.data!;
              return Column(
                children: memories.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m.category,
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.content,
                          style: TextStyle(color: AppTheme.textColor, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              );
            },
          ),

          const SizedBox(height: 48),

          // About
          Center(
            child: Text(
              'AIFace v1.0.0',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

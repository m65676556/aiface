enum LlmProvider { openai, anthropic, openrouter }

class LlmModel {
  final String id;
  final String displayName;
  final LlmProvider provider;

  const LlmModel({
    required this.id,
    required this.displayName,
    required this.provider,
  });

  static const List<LlmModel> availableModels = [
    LlmModel(id: 'gpt-4o', displayName: 'GPT-4o', provider: LlmProvider.openai),
    LlmModel(id: 'gpt-4o-mini', displayName: 'GPT-4o Mini', provider: LlmProvider.openai),
    LlmModel(id: 'claude-sonnet-4-5-20250929', displayName: 'Claude Sonnet 4.5', provider: LlmProvider.anthropic),
    LlmModel(id: 'claude-haiku-4-5-20251001', displayName: 'Claude Haiku 4.5', provider: LlmProvider.anthropic),
    LlmModel(id: 'deepseek/deepseek-chat:free', displayName: 'DeepSeek Chat (Free)', provider: LlmProvider.openrouter),
    LlmModel(id: 'deepseek/deepseek-r1:free', displayName: 'DeepSeek R1 (Free)', provider: LlmProvider.openrouter),
    LlmModel(id: 'meta-llama/llama-3.3-70b-instruct:free', displayName: 'Llama 3.3 70B (Free)', provider: LlmProvider.openrouter),
    LlmModel(id: 'openai/gpt-4o-mini', displayName: 'GPT-4o Mini (OR)', provider: LlmProvider.openrouter),
  ];
}

class LlmConfig {
  final String? openaiApiKey;
  final String? anthropicApiKey;
  final String? openrouterApiKey;
  final String selectedModelId;

  const LlmConfig({
    this.openaiApiKey,
    this.anthropicApiKey,
    this.openrouterApiKey,
    this.selectedModelId = 'gpt-4o-mini',
  });

  LlmModel get selectedModel =>
      LlmModel.availableModels.firstWhere(
        (m) => m.id == selectedModelId,
        orElse: () => LlmModel.availableModels.first,
      );

  String? get activeApiKey {
    switch (selectedModel.provider) {
      case LlmProvider.openai:
        return openaiApiKey;
      case LlmProvider.anthropic:
        return anthropicApiKey;
      case LlmProvider.openrouter:
        return openrouterApiKey;
    }
  }

  LlmConfig copyWith({
    String? openaiApiKey,
    String? anthropicApiKey,
    String? openrouterApiKey,
    String? selectedModelId,
  }) {
    return LlmConfig(
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      openrouterApiKey: openrouterApiKey ?? this.openrouterApiKey,
      selectedModelId: selectedModelId ?? this.selectedModelId,
    );
  }
}

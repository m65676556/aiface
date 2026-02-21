import '../../data/models/llm_config.dart';
import 'llm_service.dart';
import 'openai_service.dart';
import 'anthropic_service.dart';
import 'openrouter_service.dart';

class LlmFactory {
  static LlmService create(LlmConfig config) {
    final model = config.selectedModel;
    final apiKey = config.activeApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key not configured for ${model.provider.name}');
    }

    switch (model.provider) {
      case LlmProvider.openai:
        return OpenAiService(apiKey: apiKey, model: model.id);
      case LlmProvider.anthropic:
        return AnthropicService(apiKey: apiKey, model: model.id);
      case LlmProvider.openrouter:
        return OpenRouterService(apiKey: apiKey, model: model.id);
    }
  }
}

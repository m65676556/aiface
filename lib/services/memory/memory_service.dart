import 'dart:convert';
import '../../data/models/message.dart';
import '../llm/llm_service.dart';

class MemoryService {
  static const String _extractionPrompt = '''Analyze the following conversation and extract key facts about the user.
Return ONLY a JSON array of objects with "content" and "category" fields.
Categories: "preference" (things the user likes/dislikes), "fact" (factual information about the user), "context" (situational context).
If no meaningful facts can be extracted, return an empty array [].
Be concise. Each fact should be one sentence.

Conversation:
''';

  Future<List<Map<String, String>>> extractMemories(
    LlmService llm,
    List<Message> recentMessages,
  ) async {
    if (recentMessages.isEmpty) return [];

    final conversationText = recentMessages
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    try {
      final response = await llm.chat(
        [
          Message(
            id: 'extraction',
            conversationId: '',
            role: 'user',
            content: '$_extractionPrompt$conversationText',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final jsonStr = _extractJsonArray(response);
      if (jsonStr == null) return [];

      final List<dynamic> parsed = jsonDecode(jsonStr) as List<dynamic>;
      return parsed
          .map((item) => {
                'content': (item as Map<String, dynamic>)['content']?.toString() ?? '',
                'category': item['category']?.toString() ?? 'fact',
              })
          .where((m) => m['content']!.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  String? _extractJsonArray(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  String buildMemoryContext(List<String> memories) {
    if (memories.isEmpty) return '';
    final memStr = memories.map((m) => '- $m').join('\n');
    return '\n\nThings I remember about you:\n$memStr';
  }
}

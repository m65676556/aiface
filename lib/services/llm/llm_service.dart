import '../../data/models/message.dart';

abstract class LlmService {
  String get providerName;

  Future<String> chat(
    List<Message> messages, {
    String? systemPrompt,
  });

  Stream<String> streamChat(
    List<Message> messages, {
    String? systemPrompt,
  });

  Future<bool> testConnection();
}

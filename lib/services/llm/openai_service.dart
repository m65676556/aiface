import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/message.dart';
import 'llm_service.dart';

class OpenAiService implements LlmService {
  final String apiKey;
  final String model;
  final Dio _dio;

  OpenAiService({
    required this.apiKey,
    required this.model,
  }) : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.openai.com/v1',
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  String get providerName => 'OpenAI';

  List<Map<String, dynamic>> _buildMessages(
      List<Message> messages, String? systemPrompt) {
    final result = <Map<String, dynamic>>[];

    if (systemPrompt != null) {
      result.add({'role': 'system', 'content': systemPrompt});
    }

    for (final msg in messages) {
      if (msg.imageBase64 != null && msg.role == 'user') {
        result.add({
          'role': msg.role,
          'content': [
            {'type': 'text', 'text': msg.content},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${msg.imageBase64}',
              },
            },
          ],
        });
      } else {
        result.add({
          'role': msg.role,
          'content': msg.content,
        });
      }
    }
    return result;
  }

  @override
  Future<String> chat(
    List<Message> messages, {
    String? systemPrompt,
  }) async {
    final response = await _dio.post('/chat/completions', data: {
      'model': model,
      'messages': _buildMessages(messages, systemPrompt),
      'max_tokens': 1024,
    });

    return response.data['choices'][0]['message']['content'] as String;
  }

  @override
  Stream<String> streamChat(
    List<Message> messages, {
    String? systemPrompt,
  }) async* {
    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': model,
        'messages': _buildMessages(messages, systemPrompt),
        'max_tokens': 1024,
        'stream': true,
      },
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (line.startsWith('data: ') && line != 'data: [DONE]') {
          try {
            final json = jsonDecode(line.substring(6));
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null) yield delta;
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _dio.post('/chat/completions', data: {
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Hi'}
        ],
        'max_tokens': 5,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

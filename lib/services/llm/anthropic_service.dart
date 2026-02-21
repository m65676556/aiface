import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/message.dart';
import 'llm_service.dart';

class AnthropicService implements LlmService {
  final String apiKey;
  final String model;
  final Dio _dio;

  AnthropicService({
    required this.apiKey,
    required this.model,
  }) : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.anthropic.com/v1',
          headers: {
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ));

  @override
  String get providerName => 'Anthropic';

  List<Map<String, dynamic>> _buildMessages(List<Message> messages) {
    final result = <Map<String, dynamic>>[];

    for (final msg in messages) {
      if (msg.role == 'system') continue;

      if (msg.imageBase64 != null && msg.role == 'user') {
        result.add({
          'role': msg.role,
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': msg.imageBase64,
              },
            },
            {'type': 'text', 'text': msg.content},
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
    final response = await _dio.post('/messages', data: {
      'model': model,
      'max_tokens': 1024,
      if (systemPrompt != null) 'system': systemPrompt,
      'messages': _buildMessages(messages),
    });

    final content = response.data['content'] as List;
    return content.map((c) => c['text']).join();
  }

  @override
  Stream<String> streamChat(
    List<Message> messages, {
    String? systemPrompt,
  }) async* {
    final response = await _dio.post(
      '/messages',
      data: {
        'model': model,
        'max_tokens': 1024,
        'stream': true,
        if (systemPrompt != null) 'system': systemPrompt,
        'messages': _buildMessages(messages),
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
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6));
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'];
              if (text != null) yield text;
            }
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _dio.post('/messages', data: {
        'model': model,
        'max_tokens': 5,
        'messages': [
          {'role': 'user', 'content': 'Hi'}
        ],
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

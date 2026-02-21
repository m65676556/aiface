import 'package:dio/dio.dart';
import '../core/constants.dart';

class DatingApiService {
  static final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.vercelApiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<void> publishProfile(Map<String, dynamic> data) async {
    await _dio.post('/api/profile', data: data);
  }

  static Future<List<Map<String, dynamic>>> fetchMatches(
      String deviceId) async {
    final resp =
        await _dio.get('/api/matches', queryParameters: {'device_id': deviceId});
    final list = resp.data as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> sendMessage(
      String fromId, String toId, String content) async {
    await _dio.post('/api/messages',
        data: {'from_id': fromId, 'to_id': toId, 'content': content});
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(
      String fromId, String toId, String afterIso) async {
    final resp = await _dio.get('/api/messages', queryParameters: {
      'from_id': fromId,
      'to_id': toId,
      'after': afterIso,
    });
    final list = resp.data as List;
    return list.cast<Map<String, dynamic>>();
  }
}

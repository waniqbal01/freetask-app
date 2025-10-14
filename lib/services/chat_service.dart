import 'dart:io';

import 'package:dio/dio.dart';

import '../models/chat.dart';
import '../models/message.dart';
import 'api_client.dart';

class ChatService {
  ChatService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ChatThread>> fetchThreads() async {
    try {
      final response = await _apiClient.client.get<List<dynamic>>('/chat');
      final data = response.data ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(ChatThread.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ChatException(_mapError(error));
    }
  }

  Future<List<Message>> fetchMessages(String chatId) async {
    try {
      final response = await _apiClient.client.get<List<dynamic>>(
        '/chat/$chatId/messages',
      );
      final data = response.data ?? const [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList();
    } on DioException catch (error) {
      throw ChatException(_mapError(error));
    }
  }

  Future<Message> sendMessage({
    required String chatId,
    required String text,
    File? image,
  }) async {
    try {
      final formData = FormData.fromMap({
        'text': text,
        if (image != null)
          'image': await MultipartFile.fromFile(
            image.path,
            filename: image.uri.pathSegments.isNotEmpty
                ? image.uri.pathSegments.last
                : 'attachment.jpg',
          ),
      });
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/chat/$chatId/messages',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = response.data ?? <String, dynamic>{};
      return Message.fromJson(data);
    } on DioException catch (error) {
      throw ChatException(_mapError(error));
    }
  }

  String _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please try again.';
    }
    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['message'] is String) {
          return data['message'] as String;
        }
        if (data['error'] is String) {
          return data['error'] as String;
        }
      }
      switch (response.statusCode) {
        case 401:
          return 'Session expired. Please login again.';
        case 404:
          return 'Chat not found.';
        default:
          return 'Server error (${response.statusCode}).';
      }
    }
    return 'Something went wrong. Please try again later.';
  }
}

class ChatException implements Exception {
  ChatException(this.message);

  final String message;

  @override
  String toString() => 'ChatException: $message';
}

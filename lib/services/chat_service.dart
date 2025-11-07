import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/role_permission.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/pending_message.dart';
import 'session_api_client.dart';
import 'chat_cache_service.dart';

class ChatService {
  ChatService(this._apiClient, this._cacheService);

  final SessionApiClient _apiClient;
  final ChatCacheService _cacheService;

  Future<List<ChatThread>> fetchThreads() async {
    try {
      final response = await _apiClient.client.get<List<dynamic>>(
        '/chat',
        options: _apiClient.guard(permission: RolePermission.viewChats),
      );
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
        options: _apiClient.guard(permission: RolePermission.viewChats),
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
    List<File> attachments = const [],
  }) async {
    try {
      for (final attachment in attachments) {
        if (!attachment.existsSync()) continue;
        final size = attachment.lengthSync();
        if (size > 10 * 1024 * 1024) {
          throw ChatException('Attachments must be 10MB or smaller.');
        }
      }
      return await _performSend(
        chatId: chatId,
        text: text,
        attachments: attachments,
      );
    } on DioException catch (error) {
      if (_isOffline(error)) {
        throw ChatException('Unable to send message while offline. It will retry automatically.');
      }
      throw ChatException(_mapError(error));
    }
  }

  Future<void> markMessagesRead({
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    try {
      await _apiClient.client.post<void>(
        '/chat/$chatId/read',
        data: {'messageIds': messageIds},
        options: _apiClient.guard(permission: RolePermission.viewChats),
      );
    } on DioException catch (error) {
      throw ChatException(_mapError(error));
    }
  }

  Future<void> flushPendingQueues() async {
    final chatIds = _cacheService.getPendingChatIds();
    for (final chatId in chatIds) {
      final queue = _cacheService.getPendingMessages(chatId);
      if (queue.isEmpty) {
        await _cacheService.clearPendingMessages(chatId);
        continue;
      }
      final remaining = <PendingMessage>[];
      for (final pending in queue) {
        try {
          final files = pending.attachments
              .map((attachment) => File(attachment.path))
              .where((file) => file.existsSync())
              .toList();
          await _performSend(
            chatId: chatId,
            text: pending.text,
            attachments: files,
          );
        } catch (_) {
          remaining.add(pending);
        }
      }
      if (remaining.isEmpty) {
        await _cacheService.clearPendingMessages(chatId);
      } else {
        await _cacheService.savePendingMessages(chatId, remaining);
      }
    }
  }

  Future<Message> _performSend({
    required String chatId,
    required String text,
    List<File> attachments = const [],
  }) async {
    final files = <MultipartFile>[];
    for (final attachment in attachments) {
      files.add(
        await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.uri.pathSegments.isNotEmpty
              ? attachment.uri.pathSegments.last
              : 'attachment-${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    }
    final formData = FormData();
    formData.fields.add(MapEntry('text', text));
    if (files.isNotEmpty) {
      formData.files.addAll(files.map((file) => MapEntry('attachments', file)));
    }
    final response = await _apiClient.client.post<Map<String, dynamic>>(
      '/chat/$chatId/messages',
      data: formData,
      options: _apiClient
          .guard(permission: RolePermission.viewChats)
          .copyWith(contentType: 'multipart/form-data'),
    );
    final data = response.data ?? <String, dynamic>{};
    return Message.fromJson(data);
  }

  bool _isOffline(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.error is SocketException;
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

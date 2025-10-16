import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../models/pending_message.dart';

class ChatCacheService {
  ChatCacheService(this._prefs);

  static const _lastMessagePrefix = 'chat:last_message:';
  static const _pendingQueuePrefix = 'chat:pending_queue:';

  final SharedPreferences _prefs;

  Future<void> cacheLastMessage(String chatId, Message message) async {
    final key = '$_lastMessagePrefix$chatId';
    final data = message.toJson();
    await _prefs.setString(key, jsonEncode(data));
  }

  Message? getCachedLastMessage(String chatId) {
    final key = '$_lastMessagePrefix$chatId';
    final data = _prefs.getString(key);
    if (data == null) return null;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return Message.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> savePendingMessages(String chatId, List<PendingMessage> queue) async {
    final key = '$_pendingQueuePrefix$chatId';
    final list = queue.map((item) => item.toJson()).toList();
    await _prefs.setString(key, jsonEncode(list));
  }

  List<PendingMessage> getPendingMessages(String chatId) {
    final key = '$_pendingQueuePrefix$chatId';
    final data = _prefs.getString(key);
    if (data == null) return const [];
    try {
      final decoded = jsonDecode(data);
      if (decoded is List<dynamic>) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(PendingMessage.fromJson)
            .toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  Future<void> clearPendingMessages(String chatId) async {
    final key = '$_pendingQueuePrefix$chatId';
    await _prefs.remove(key);
  }
}

import 'dart:convert';

import 'key_value_store.dart';
import '../models/message.dart';
import '../models/pending_message.dart';

class ChatCacheService {
  ChatCacheService(this._store);

  static const _lastMessagePrefix = 'chat:last_message:';
  static const _pendingQueuePrefix = 'chat:pending_queue:';
  static const _pendingIndexKey = 'chat:pending_index';

  final KeyValueStore _store;

  Future<void> cacheLastMessage(String chatId, Message message) async {
    final key = '$_lastMessagePrefix$chatId';
    final data = message.toJson();
    await _store.setString(key, jsonEncode(data));
  }

  Message? getCachedLastMessage(String chatId) {
    final key = '$_lastMessagePrefix$chatId';
    final data = _store.getString(key);
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
    await _store.setString(key, jsonEncode(list));
    await _updatePendingIndex(chatId, queue.isNotEmpty);
  }

  List<PendingMessage> getPendingMessages(String chatId) {
    final key = '$_pendingQueuePrefix$chatId';
    final data = _store.getString(key);
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
    await _store.remove(key);
    await _updatePendingIndex(chatId, false);
  }

  List<String> getPendingChatIds() {
    final raw = _store.getString(_pendingIndexKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList();
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }

  Future<void> _updatePendingIndex(String chatId, bool hasMessages) async {
    final ids = {...getPendingChatIds()};
    if (hasMessages) {
      ids.add(chatId);
    } else {
      ids.remove(chatId);
    }
    if (ids.isEmpty) {
      await _store.remove(_pendingIndexKey);
    } else {
      await _store.setString(_pendingIndexKey, jsonEncode(ids.toList()));
    }
  }
}

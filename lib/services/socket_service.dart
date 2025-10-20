import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
import '../models/message.dart';

class TypingEvent extends Equatable {
  const TypingEvent({
    required this.chatId,
    required this.userId,
    required this.isTyping,
  });

  final String chatId;
  final String userId;
  final bool isTyping;

  @override
  List<Object?> get props => [chatId, userId, isTyping];
}

class UserPresenceEvent extends Equatable {
  const UserPresenceEvent({
    required this.userId,
    required this.isOnline,
  });

  final String userId;
  final bool isOnline;

  @override
  List<Object?> get props => [userId, isOnline];
}

class MessageStatusUpdate extends Equatable {
  const MessageStatusUpdate({
    required this.chatId,
    required this.messageId,
    required this.status,
    this.deliveredAt,
    this.readAt,
  });

  final String chatId;
  final String messageId;
  final MessageDeliveryStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  @override
  List<Object?> get props => [chatId, messageId, status, deliveredAt, readAt];
}

class SocketService {
  SocketService();

  io.Socket? _socket;
  final _messageController = StreamController<Message>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _presenceController = StreamController<UserPresenceEvent>.broadcast();
  final _statusController = StreamController<MessageStatusUpdate>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Message> get messages => _messageController.stream;
  Stream<TypingEvent> get typing => _typingController.stream;
  Stream<UserPresenceEvent> get presence => _presenceController.stream;
  Stream<MessageStatusUpdate> get messageStatuses => _statusController.stream;
  Stream<bool> get connection => _connectionController.stream;

  void connect({required String token, required String userId}) {
    disconnect();

    final uri = Env.socketBase;
    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .enableReconnection()
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .build();

    final socket = io.io(uri, options)
      ..onConnect((_) {
        _connectionController.add(true);
        joinRoom('user:$userId');
      })
      ..onReconnect((_) {
        _connectionController.add(true);
        joinRoom('user:$userId');
      })
      ..onDisconnect((_) {
        _connectionController.add(false);
      })
      ..onError((_) {
        // keep stream subscribers alive on socket errors
      });

    _socket = socket;

    _socket?.on('message:new', (dynamic data) {
      final payload = _ensureMap(data);
      if (payload != null) {
        _messageController.add(Message.fromJson(payload));
      }
    });

    _socket?.on('chat:typing', (dynamic data) {
      final payload = _ensureMap(data);
      if (payload == null) {
        return;
      }
      final chatId = payload['chatId']?.toString();
      final typingUserId = payload['userId']?.toString();
      final isTyping =
          payload['isTyping'] == true || payload['isTyping'] == 'true';
      if (chatId != null && typingUserId != null) {
        _typingController.add(
          TypingEvent(chatId: chatId, userId: typingUserId, isTyping: isTyping),
        );
      }
    });

    _socket?.on('user:status', (dynamic data) {
      final payload = _ensureMap(data);
      if (payload == null) {
        return;
      }
      final userIdValue = payload['userId']?.toString();
      final isOnline =
          payload['isOnline'] == true || payload['isOnline'] == 'true';
      if (userIdValue != null) {
        _presenceController.add(
          UserPresenceEvent(userId: userIdValue, isOnline: isOnline),
        );
      }
    });

    _socket?.on('message:status', (dynamic data) {
      final payload = _ensureMap(data);
      if (payload == null) {
        return;
      }
      final chatId = payload['chatId']?.toString();
      final messageId = payload['messageId']?.toString();
      final statusValue = payload['status']?.toString();
      if (chatId != null && messageId != null) {
        final deliveredAtRaw = payload['deliveredAt']?.toString();
        final readAtRaw = payload['readAt']?.toString();
        _statusController.add(
          MessageStatusUpdate(
            chatId: chatId,
            messageId: messageId,
            status: MessageDeliveryStatusX.fromValue(statusValue),
            deliveredAt:
                deliveredAtRaw == null ? null : DateTime.tryParse(deliveredAtRaw),
            readAt: readAtRaw == null ? null : DateTime.tryParse(readAtRaw),
          ),
        );
      }
    });
  }

  Map<String, dynamic>? _ensureMap(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data as Map<dynamic, dynamic>);
    }
    return null;
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void joinRoom(String room) {
    emit('join', room);
  }

  void leaveRoom(String room) {
    emit('leave', room);
  }

  void joinChatRoom(String chatId) {
    joinRoom('chat:$chatId');
  }

  void leaveChatRoom(String chatId) {
    leaveRoom('chat:$chatId');
  }

  void sendTyping({required String chatId, required bool isTyping}) {
    emit('chat:typing', {
      'chatId': chatId,
      'isTyping': isTyping,
    });
  }

  void sendReadReceipt({
    required String chatId,
    required List<String> messageIds,
  }) {
    if (messageIds.isEmpty) return;
    emit('message:read', {
      'chatId': chatId,
      'messageIds': messageIds,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _presenceController.close();
    _statusController.close();
    _connectionController.close();
  }
}

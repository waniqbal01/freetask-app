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
      ..on('message:new', (data) {
        if (data is Map<String, dynamic>) {
          _messageController.add(Message.fromJson(data));
        }
      })
      ..on('chat:typing', (data) {
        if (data is Map<String, dynamic>) {
          final chatId = data['chatId']?.toString();
          final typingUserId = data['userId']?.toString();
          final isTyping = data['isTyping'] == true || data['isTyping'] == 'true';
          if (chatId != null && typingUserId != null) {
            _typingController.add(
              TypingEvent(chatId: chatId, userId: typingUserId, isTyping: isTyping),
            );
          }
        }
      })
      ..on('user:status', (data) {
        if (data is Map<String, dynamic>) {
          final userIdValue = data['userId']?.toString();
          final isOnline = data['isOnline'] == true || data['isOnline'] == 'true';
          if (userIdValue != null) {
            _presenceController.add(
              UserPresenceEvent(userId: userIdValue, isOnline: isOnline),
            );
          }
        }
      })
      ..on('message:status', (data) {
        if (data is Map<String, dynamic>) {
          final chatId = data['chatId']?.toString();
          final messageId = data['messageId']?.toString();
          final statusValue = data['status']?.toString();
          if (chatId != null && messageId != null) {
            final deliveredAtRaw = data['deliveredAt']?.toString();
            final readAtRaw = data['readAt']?.toString();
            _statusController.add(
              MessageStatusUpdate(
                chatId: chatId,
                messageId: messageId,
                status: MessageDeliveryStatusX.fromValue(statusValue),
                deliveredAt: deliveredAtRaw == null
                    ? null
                    : DateTime.tryParse(deliveredAtRaw),
                readAt:
                    readAtRaw == null ? null : DateTime.tryParse(readAtRaw),
              ),
            );
          }
        }
      })
      ..onError((_) {
        // keep stream subscribers alive on socket errors
      });

    _socket = socket;
  }

  void on<T>(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
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

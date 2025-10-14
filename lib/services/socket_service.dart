import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
import '../models/message.dart';

class SocketService {
  SocketService();

  io.Socket? _socket;
  final _messageController = StreamController<Message>.broadcast();

  Stream<Message> get messages => _messageController.stream;

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
        socket.emit('join', 'user:$userId');
      })
      ..onDisconnect((_) {})
      ..on('message:new', (data) {
        if (data is Map<String, dynamic>) {
          _messageController.add(Message.fromJson(data));
        }
      })
      ..onError((error) {
        // ignore errors but keep stream safe
      });

    _socket = socket;
  }

  void joinChatRoom(String chatId) {
    _socket?.emit('join', 'chat:$chatId');
  }

  void leaveChatRoom(String chatId) {
    _socket?.emit('leave', 'chat:$chatId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}

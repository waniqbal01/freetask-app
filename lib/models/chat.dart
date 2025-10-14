import 'package:equatable/equatable.dart';

import 'message.dart';

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id']?.toString() ?? '',
      participants: (json['participants'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      lastMessage: json['lastMessage'] is Map<String, dynamic>
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unreadCount'] is int
          ? json['unreadCount'] as int
          : int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
    );
  }

  final String id;
  final List<String> participants;
  final Message? lastMessage;
  final int unreadCount;

  ChatThread copyWith({
    String? id,
    List<String>? participants,
    Message? lastMessage,
    int? unreadCount,
  }) {
    return ChatThread(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [id, participants, lastMessage, unreadCount];
}

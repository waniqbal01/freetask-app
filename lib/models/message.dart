import 'package:equatable/equatable.dart';

class Message extends Equatable {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.attachments,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['text'] as String? ?? '',
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final List<String> attachments;
  final DateTime createdAt;

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    List<String>? attachments,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, chatId, senderId, text, attachments, createdAt];
}

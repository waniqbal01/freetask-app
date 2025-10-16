import 'package:equatable/equatable.dart';

import 'message_attachment.dart';

enum MessageDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

extension MessageDeliveryStatusX on MessageDeliveryStatus {
  static MessageDeliveryStatus fromValue(String? value) {
    switch (value) {
      case 'read':
        return MessageDeliveryStatus.read;
      case 'delivered':
        return MessageDeliveryStatus.delivered;
      case 'failed':
        return MessageDeliveryStatus.failed;
      case 'sending':
        return MessageDeliveryStatus.sending;
      case 'sent':
      default:
        return MessageDeliveryStatus.sent;
    }
  }

  String get value {
    switch (this) {
      case MessageDeliveryStatus.read:
        return 'read';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.failed:
        return 'failed';
      case MessageDeliveryStatus.sending:
        return 'sending';
      case MessageDeliveryStatus.sent:
        return 'sent';
    }
  }
}

class Message extends Equatable {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.attachments,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.status = MessageDeliveryStatus.sent,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString() ?? '';
    final deliveredAtRaw = json['deliveredAt']?.toString();
    final readAtRaw = json['readAt']?.toString();
    final status = MessageDeliveryStatusX.fromValue(json['status']?.toString());

    return Message(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['text'] as String? ?? '',
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MessageAttachment.fromJson)
          .toList(),
      createdAt: DateTime.tryParse(createdAtRaw) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deliveredAt: deliveredAtRaw == null
          ? null
          : DateTime.tryParse(deliveredAtRaw),
      readAt: readAtRaw == null ? null : DateTime.tryParse(readAtRaw),
      status: status == MessageDeliveryStatus.sent && readAtRaw != null
          ? MessageDeliveryStatus.read
          : status,
    );
  }

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final List<MessageAttachment> attachments;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final MessageDeliveryStatus status;

  bool get hasBeenRead => status == MessageDeliveryStatus.read || readAt != null;

  bool get hasBeenDelivered =>
      hasBeenRead || status == MessageDeliveryStatus.delivered || deliveredAt != null;

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    List<MessageAttachment>? attachments,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    MessageDeliveryStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'attachments': attachments.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'status': status.value,
    };
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        text,
        attachments,
        createdAt,
        deliveredAt,
        readAt,
        status,
      ];
}

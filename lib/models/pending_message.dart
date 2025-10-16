import 'package:equatable/equatable.dart';

class PendingAttachment extends Equatable {
  const PendingAttachment({
    required this.path,
    required this.name,
    required this.mimeType,
    this.size = 0,
  });

  factory PendingAttachment.fromJson(Map<String, dynamic> json) {
    return PendingAttachment(
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      size: json['size'] is int
          ? json['size'] as int
          : int.tryParse(json['size']?.toString() ?? '0') ?? 0,
    );
  }

  final String path;
  final String name;
  final String mimeType;
  final int size;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'name': name,
      'mimeType': mimeType,
      'size': size,
    };
  }

  @override
  List<Object?> get props => [path, name, mimeType, size];
}

class PendingMessage extends Equatable {
  const PendingMessage({
    required this.localId,
    required this.chatId,
    required this.text,
    required this.attachments,
    required this.createdAt,
  });

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    return PendingMessage(
      localId: json['localId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PendingAttachment.fromJson)
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String localId;
  final String chatId;
  final String text;
  final List<PendingAttachment> attachments;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'localId': localId,
      'chatId': chatId,
      'text': text,
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PendingMessage copyWith({
    String? localId,
    String? chatId,
    String? text,
    List<PendingAttachment>? attachments,
    DateTime? createdAt,
  }) {
    return PendingMessage(
      localId: localId ?? this.localId,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [localId, chatId, text, attachments, createdAt];
}

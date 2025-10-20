import 'package:equatable/equatable.dart';

enum NotificationCategory {
  all,
  job,
  chat,
  payment,
  system,
}

extension NotificationCategoryX on NotificationCategory {
  static NotificationCategory fromValue(String? value) {
    switch (value) {
      case 'job':
        return NotificationCategory.job;
      case 'chat':
        return NotificationCategory.chat;
      case 'payment':
        return NotificationCategory.payment;
      case 'system':
        return NotificationCategory.system;
      case 'all':
      default:
        return NotificationCategory.all;
    }
  }

  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.job:
        return 'Job';
      case NotificationCategory.chat:
        return 'Chat';
      case NotificationCategory.payment:
        return 'Payment';
      case NotificationCategory.system:
        return 'System';
    }
  }

  String get value {
    switch (this) {
      case NotificationCategory.all:
        return 'all';
      case NotificationCategory.job:
        return 'job';
      case NotificationCategory.chat:
        return 'chat';
      case NotificationCategory.payment:
        return 'payment';
      case NotificationCategory.system:
        return 'system';
    }
  }
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.metadata = const <String, dynamic>{},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? json['body']?.toString() ?? '',
      category: NotificationCategoryX.fromValue(
        json['category']?.toString() ?? json['type']?.toString(),
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['read'] as bool? ?? json['isRead'] as bool? ?? false,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> metadata;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationCategory? category,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'category': category.value,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        category,
        createdAt,
        isRead,
        metadata,
      ];
}

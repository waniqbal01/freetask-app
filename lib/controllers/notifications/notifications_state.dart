import 'package:equatable/equatable.dart';

import '../../models/app_notification.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.activeTab = NotificationCategory.all,
    this.notifications = const <NotificationCategory, List<AppNotification>>{},
    this.isLoading = false,
    this.errorMessage,
  });

  final NotificationCategory activeTab;
  final Map<NotificationCategory, List<AppNotification>> notifications;
  final bool isLoading;
  final String? errorMessage;

  List<AppNotification> get activeNotifications =>
      notifications[activeTab] ?? const <AppNotification>[];

  NotificationsState copyWith({
    NotificationCategory? activeTab,
    Map<NotificationCategory, List<AppNotification>>? notifications,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      activeTab: activeTab ?? this.activeTab,
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [activeTab, notifications, isLoading, errorMessage];
}

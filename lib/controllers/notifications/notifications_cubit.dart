import 'package:bloc/bloc.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._service) : super(const NotificationsState());

  final NotificationService _service;

  Future<void> load({NotificationCategory? category}) async {
    final targetCategory = category ?? state.activeTab;
    emit(state.copyWith(isLoading: true, activeTab: targetCategory, clearError: true));
    try {
      final notifications = await _service.fetchNotifications(category: targetCategory);
      final next = Map<NotificationCategory, List<AppNotification>>.from(state.notifications)
        ..[targetCategory] = notifications;
      emit(
        state.copyWith(
          isLoading: false,
          notifications: next,
          activeTab: targetCategory,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load notifications.',
        ),
      );
    }
  }

  Future<void> markAsRead(AppNotification notification) async {
    final activeList = List<AppNotification>.from(state.activeNotifications);
    final index = activeList.indexWhere((item) => item.id == notification.id);
    if (index == -1) return;
    final updatedNotification = notification.copyWith(isRead: true);
    activeList[index] = updatedNotification;
    final next = Map<NotificationCategory, List<AppNotification>>.from(state.notifications)
      ..[state.activeTab] = activeList;
    emit(state.copyWith(notifications: next));
    try {
      await _service.markAsRead(notification.id);
    } catch (_) {
      // keep optimistic state even if request fails
    }
  }

  Future<void> changeTab(NotificationCategory category) async {
    if (state.activeTab == category) return;
    emit(state.copyWith(activeTab: category, clearError: true));
    if (!state.notifications.containsKey(category)) {
      await load(category: category);
    }
  }
}

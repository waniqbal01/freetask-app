import 'package:bloc/bloc.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._service, this._storage)
      : super(const NotificationsState());

  final NotificationService _service;
  final StorageService _storage;

  Future<void> load({NotificationCategory? category}) async {
    final targetCategory = category ?? state.activeTab;
    final token = _storage.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          activeTab: targetCategory,
          isLoading: false,
          notifications: state.notifications,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, activeTab: targetCategory, clearError: true));
    try {
      final notifications =
          await _service.fetchNotifications(token, category: targetCategory);
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
    final token = _storage.token;
    if (token == null || token.isEmpty) {
      return;
    }
    final activeList = List<AppNotification>.from(state.activeNotifications);
    final index = activeList.indexWhere((item) => item.id == notification.id);
    if (index == -1) return;
    final updatedNotification = notification.copyWith(isRead: true);
    activeList[index] = updatedNotification;
    final next = Map<NotificationCategory, List<AppNotification>>.from(state.notifications)
      ..[state.activeTab] = activeList;
    emit(state.copyWith(notifications: next));
    try {
      await _service.markAsRead(notification.id, token);
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

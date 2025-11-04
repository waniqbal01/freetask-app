import 'dart:async';

import '../auth/role_permission.dart';
import '../models/app_notification.dart';
import 'api_client.dart';

/// Lightweight notification bridge that mimics the previous Firebase-backed
/// implementation. In the pure Dart environment the service simply exposes a
/// stream that tests can add messages to manually.
class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _initialized = false;

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> initialize() async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  Future<void> registerToken(String token) async {
    await _apiClient.client.post<void>(
      '/users/me/fcm-token',
      data: {'token': token},
      options: _apiClient.guard(permission: RolePermission.viewNotifications),
    );
  }

  Future<List<AppNotification>> fetchNotifications({
    NotificationCategory category = NotificationCategory.all,
  }) async {
    final response = await _apiClient.client.get<List<dynamic>>(
      '/notifications',
      queryParameters: {
        if (category != NotificationCategory.all) 'category': category.value,
      },
      options: _apiClient.guard(permission: RolePermission.viewNotifications),
    );
    final data = response.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.client.post<void>(
      '/notifications/$id/read',
      options: _apiClient.guard(permission: RolePermission.viewNotifications),
    );
  }

  /// Allows tests to inject a message into the stream.
  void pushMessage(Map<String, dynamic> message) {
    if (!_controller.isClosed) {
      _controller.add(message);
    }
  }

  void dispose() {
    _controller.close();
  }
}

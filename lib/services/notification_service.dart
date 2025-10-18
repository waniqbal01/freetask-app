import 'dart:async';

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

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';

class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;
  final _controller = StreamController<RemoteMessage>.broadcast();
  bool _initialized = false;

  Stream<RemoteMessage> get messages => _controller.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // ignore errors for cases where firebase is already initialized
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        _initialized = true;
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _sendToken(token);
      }

      FirebaseMessaging.onMessage.listen(_controller.add);
      FirebaseMessaging.onTokenRefresh.listen(_sendToken);
    } catch (_) {
      // ignore when firebase messaging is unavailable
    } finally {
      _initialized = true;
    }
  }

  Future<void> _sendToken(String token) async {
    try {
      await _apiClient.client.post<void>(
        '/users/me/fcm-token',
        data: {'token': token},
      );
    } catch (_) {
      // ignore errors silently to avoid disrupting UX
    }
  }

  void dispose() {
    _controller.close();
  }
}

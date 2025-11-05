import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/env.dart';

class NotificationService {
  static bool _initialized = false;
  static final _orderEvents = StreamController<String>.broadcast();

  static Stream<String> get orderEvents => _orderEvents.stream;

  static Future<void> init() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    await FirebaseCrashlytics.instance.setCustomKey('app_env', Env.appEnv);
    await FirebaseCrashlytics.instance.setCustomKey('app_release', Env.appRelease);

    final notif = FirebaseMessaging.instance;
    await notif.requestPermission();
    final token = await notif.getToken();
    // TODO: POST token to server for user binding.

    FirebaseMessaging.onMessage.listen((msg) {
      final t = msg.data['type'] ?? '';
      if (t == 'order_update') {
        _orderEvents.add(msg.data['orderId'] ?? '');
      }
    });

    _initialized = true;
  }
}

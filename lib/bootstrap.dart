import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:freetask_app/config/app_env.dart';

SentryEvent? _beforeSend(SentryEvent event, {Hint? hint}) {
  try {
    final user = event.user;
    if (user != null) {
      final sanitizedUser = user.copyWith(
        email: user.email != null ? '***@***' : null,
        username: user.username != null ? '***' : null,
      );
      return event.copyWith(user: sanitizedUser);
    }
  } catch (_) {}
  return event;
}

Future<void> bootstrap(Future<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnv.enableSentry && AppEnv.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppEnv.sentryDsn;
        options.tracesSampleRate = 1.0;
        options.beforeSend = _beforeSend;
      },
      appRunner: () async => runApp(await builder()),
    );
  } else {
    runApp(await builder());
  }
}

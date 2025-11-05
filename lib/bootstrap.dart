import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:freetask_app/config/app_env.dart';

Future<void> bootstrap(Future<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnv.enableSentry && AppEnv.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppEnv.sentryDsn;
        options.tracesSampleRate = 1.0;
        // Define with the exact typedef from package:sentry
        SentryEvent? beforeSend(SentryEvent event, {dynamic hint}) {
          return event;
        }
        options.beforeSend = beforeSend;
      },
      appRunner: () async => runApp(await builder()),
    );
  } else {
    runApp(await builder());
  }
}

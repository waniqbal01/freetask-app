import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry/sentry.dart' as sentry;
import 'package:freetask_app/config/app_env.dart';

Future<void> bootstrap(Future<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnv.enableSentry && AppEnv.sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = AppEnv.sentryDsn;
        options.tracesSampleRate = 1.0;
        // Use exact types from package:sentry to satisfy BeforeSendCallback
        options.beforeSend = (sentry.SentryEvent event, {sentry.Hint? hint}) {
          return event; // sentry.SentryEvent? (sync) matches sentry.BeforeSendCallback
        };
      },
      appRunner: () async => runApp(await builder()),
    );
  } else {
    runApp(await builder());
  }
}

import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final bootstrap = await AppBootstrap.init();
    runApp(FreetaskApp(bootstrap: bootstrap));
  } catch (error, stackTrace) {
    appLog('Failed to start application', error: error, stackTrace: stackTrace);
    rethrow;
  }
}

#!/usr/bin/env bash
set -e
flutter build appbundle \
  --release \
  --dart-define=API_BASE=https://api.freetask.my \
  --dart-define=SOCKET_BASE=https://api.freetask.my \
  --dart-define=SENTRY_DSN=YOUR_SENTRY_DSN \
  --dart-define=APP_ENV=production \
  --dart-define=APP_RELEASE=freetask-app@1.0.0

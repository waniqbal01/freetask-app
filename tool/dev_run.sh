#!/usr/bin/env bash
set -e
flutter run \
  --dart-define=API_BASE=http://10.0.2.2:4000 \
  --dart-define=SOCKET_BASE=http://10.0.2.2:4000 \
  --dart-define=SENTRY_DSN= \
  --dart-define=APP_ENV=beta \
  --dart-define=APP_RELEASE=freetask-app@1.0.0

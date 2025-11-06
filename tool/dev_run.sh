#!/usr/bin/env bash
set -e
flutter run \
  --dart-define=API_BASE_URL=https://localhost:4000 \
  --dart-define=ENABLE_SENTRY=false \
  --dart-define=APP_NAME="Freetask Dev" \
  --dart-define=SENTRY_DSN=""

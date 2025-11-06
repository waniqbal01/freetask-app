#!/usr/bin/env bash
set -e
FLAVOR=${1:-prod}
case "$FLAVOR" in
  dev)
    API_BASE_URL="https://localhost:4000"
    ENABLE_SENTRY=false
    APP_NAME="Freetask Dev"
    SENTRY_DSN=""
    ;;
  stg)
    API_BASE_URL="https://stg.api.freetask.my"
    ENABLE_SENTRY=true
    APP_NAME="Freetask Staging"
    SENTRY_DSN="__ISI_DSN_STG__"
    ;;
  prod|production)
    API_BASE_URL="https://api.freetask.my"
    ENABLE_SENTRY=true
    APP_NAME="Freetask"
    SENTRY_DSN="__ISI_DSN_PROD__"
    ;;
  *)
    echo "Unknown flavor: $FLAVOR"; exit 1;;
esac
flutter build apk --release \
  --dart-define=API_BASE_URL=$API_BASE_URL \
  --dart-define=ENABLE_SENTRY=$ENABLE_SENTRY \
  --dart-define=APP_NAME="$APP_NAME" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"
echo "✅ Built $FLAVOR"

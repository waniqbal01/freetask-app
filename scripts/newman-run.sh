#!/usr/bin/env bash
set -euo pipefail

COLLECTION="${COLLECTION_PATH:-postman/freetask-e2e.postman_collection.json}"
ENV_FILE="${ENV_PATH:-postman/environments/local.postman_environment.json}"
REPORT_DIR="postman/reports"
REPORT_FILE="$REPORT_DIR/newman-report.html"

mkdir -p "$REPORT_DIR"

npx --yes newman run "$COLLECTION" \
  --environment "$ENV_FILE" \
  --reporters cli,html \
  --reporter-html-export "$REPORT_FILE"

echo "Newman HTML report saved to $REPORT_FILE"

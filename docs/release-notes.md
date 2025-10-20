# Release Notes – Freetask Platform

## Scope
- OTP authentication happy-path automation (Postman + Newman).
- Load/performance coverage for auth, jobs, payments.
- Full-stack observability via Sentry (API) and Crashlytics/Sentry (app).
- Deployment guardrails and Go/No-Go standards.

## Changes
- Added `postman/freetask-e2e.postman_collection.json` with scripted happy and negative flows.
- Introduced reusable Newman (`scripts/newman-run.sh`) and k6 (`scripts/k6-load-test.js`) tooling.
- Wired Sentry tagging (release/env/requestId) across Flutter app & Node API.
- Attempt Crashlytics bootstrap with environment-provided Firebase options.
- Documented deployment SOP, Sentry alert policies, and operational checklists.

## Fixes / Hardening
- Captured backend errors and audit breadcrumbs in Sentry with graceful shutdown flushing.
- Propagated `requestId` context from API responses into mobile monitoring pipelines.
- Hardened HTTP client error handling with automatic telemetry for 5xx responses.

## Known Issues
- Crashlytics requires runtime Firebase credentials; without them the SDK remains disabled (logged in console).
- OTP login still rate-limited to 5/min per IP—load tests should size VUs accordingly.
- Existing integration tests do not yet cover Crashlytics fallbacks; monitor logs for failures during CI.

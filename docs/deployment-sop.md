# Deployment SOP (Blue-Green / Rolling)

## 1. Pre-deployment

1. **Code quality gates**
   - `flutter analyze` and `flutter test`
   - `npm run lint`/`npm test` for API (add when available)
2. **Database readiness**
   - Run pending migrations on the *idle* environment (Blue or Green) using the feature branch build.
   - Verify schema diff is backward compatible.
3. **Artifacts**
   - Build Flutter release bundle / app bundle.
   - Build API container image tagged with `APP_RELEASE`.
4. **Monitoring hooks**
   - Update Sentry release with commits and deploy start timestamp.
   - Confirm alert rules (crash-free ≥99%, payment_success ≥98%, 5xx <0.5%) are active.

## 2. Deployment

### Blue-Green
1. Deploy the new release to the *idle* color (e.g., Green) behind the load balancer.
2. Run database migrations (if not yet applied) against Green only.
3. Perform readiness checks:
   - `GET /healthz` → expect HTTP 200.
   - `GET /readyz` repeatedly until stable for 60s.
4. Shift traffic gradually (e.g., 10% → 50% → 100%) while monitoring latency and error dashboards.
5. Keep the previous color (Blue) warm for quick rollback.

### Rolling (per AZ or node)
1. Drain traffic from the target instance.
2. Apply rolling update with a minimum 1 healthy surge instance.
3. Each instance must pass readiness probe before joining the pool.
4. Enforce graceful shutdown (SIGTERM → wait for in-flight requests ≤30s) so Sentry flush completes.

## 3. Post-deployment

1. **Smoke test (3–5 minutes)**
   - Auth OTP login → create job → freelancer apply → chat message → escrow → release.
   - Use Postman collection `postman/freetask-e2e.postman_collection.json` or automated check.
2. **Metrics verification**
   - `http_req_duration` P95 < 1s, P50 < 400ms (k6 dashboard or APM).
   - Crash-free sessions dashboard ≥ 99%.
   - Payment success SLO ≥ 98%.
   - 5xx rate < 0.5%.
3. **Observability**
   - Confirm Sentry deploy marked as finished (`sentry-cli releases finalize`).
   - Review Crashlytics dashboards for new issues.
4. **Comms**
   - Publish release notes (see `docs/release-notes.md`).
   - Notify stakeholders in `#shiproom` with Go/No-Go status.

## 4. Rollback Criteria & Procedure

Trigger rollback if **any** of the following occur within the first 30 minutes:
- API latency P95 > 1s sustained for >5 minutes.
- Error rate > 1% (either 5xx or failed payments).
- Smoke test red / degraded.

**Rollback steps:**
1. Re-route traffic back to the previous color (Blue) or scale down the new pods.
2. Revert feature flags / config overrides introduced in the release.
3. If migrations are not backward compatible, execute down migration plan.
4. Notify incident channel and open a retro ticket.
5. Leave Sentry deploy marked as failed for traceability.

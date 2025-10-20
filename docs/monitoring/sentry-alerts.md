# Sentry Alert Policies

> Target release health KPIs
>
> * Crash-free sessions ≥ 99%
> * `payment_success` transaction rate ≥ 98%
> * 5xx error rate < 0.5%

## Release Health Alert (Crash-free Sessions)

Create a **Release Health** alert in Sentry with the following configuration:

```yaml
name: Crash-free sessions below target
dataset: release_health
query: "session.crash_free_rate < 99"
aggregate: "session.crash_free_rate"
thresholdType: below
resolveThreshold: 99.2
projects: [freetask-app]
environments: [production, staging]
frequency: 5m
actions:
  - type: slack
    channel: "#oncall-freetask"
    tags:
      release: {{release}}
      env: {{environment}}
```

## Transaction Success Alert (Payments)

Use a **Performance** alert on the `payment_success` transaction name emitted by the API:

```yaml
name: Payment success rate degraded
dataset: transactions
query: "transaction:payment_success"
aggregate: "percentage(transaction.duration, less, 120000)"
thresholdType: below
alertThreshold: 98
resolveThreshold: 99
projects: [freetask-api]
environments: [production]
frequency: 5m
actions:
  - type: email
    targetType: team
    targetIdentifier: payments-guardians
  - type: pagerduty
    integration: freetask-core
```

## 5xx Rate Alert

```yaml
name: API 5xx error budget burn
dataset: events
query: "event.type:error level:error http.status_code:[500,599]"
aggregate: "percentage(count(), by, http.status_code)"
thresholdType: above
alertThreshold: 0.5
resolveThreshold: 0.2
projects: [freetask-api]
environments: [production, staging]
frequency: 1m
actions:
  - type: slack
    channel: "#incidents"
  - type: issue_alert
    assignee: oncall
```

> **Tip:** Attach tags `release`, `environment`, and `requestId` to every captured event (already configured in code) so that the alert payloads automatically include troubleshooting pivots.

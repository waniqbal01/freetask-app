# Go / No-Go Checklist

| Item | Target | Status |
|------|--------|--------|
| Crash-free sessions | ≥ 99% | ☐ |
| Payment success rate | ≥ 98% | ☐ |
| API error rate (5xx) | < 0.5% | ☐ |
| Happy-path automation | 100% green | ☐ |
| Repeated auth failures (401) | ≤ 1/day | ☐ |
| Not-found errors (404) | ≤ 1/day | ☐ |
| Gateway errors (502) | ≤ 1/day | ☐ |
| Latency P50 | < 400 ms | ☐ |
| Latency P95 | < 1 s | ☐ |
| Deployment SOP followed | Yes | ☐ |
| Smoke test (Auth→Post→Apply→Chat→Payment) | Pass | ☐ |

> Mark each item once the corresponding dashboard or automated check confirms compliance. A single ❌ flips the release to **No-Go** until remediated.

# FreeTask Modular API Server

This lightweight Node.js server provides a modular reference implementation for the FreeTask marketplace backend.
It is designed for local development and integration testing alongside the Flutter client.

## Features

- JWT access tokens with refresh tokens and OTP login flow (401 vs 403 responses enforced)
- Modular route handlers for Users, Jobs, Bids, Chat, Payments, Wallet, Notifications, and Reviews
- Job lifecycle enforcement (OPEN → IN_PROGRESS → COMPLETED with optional CANCELLED)
- Real-time chat via WebSocket handshake (including `typing` event broadcast)
- Escrow and release flows with idempotency keys and Billplz/Stripe webhook ingestion
- Per-request requestId propagation + audit logging (userId, action, entity, requestId)
- Sentry instrumentation with release/environment/requestId tagging and graceful shutdown flushing
- Pagination across list endpoints with projection responses to minimise payload size
- In-memory rate limiting on login/OTP flows and 10MB chat attachment guard with virus-scan stub
- Health (`/healthz`) and readiness (`/readyz`) endpoints plus graceful shutdown hooks
- Retry policy hint via `Cache-Control: no-store` on idempotent GET requests only
- Simulated DB indexes via keyed Maps on jobs (`status/category/createdAt`), bids (`jobId/userId`), and chat (`jobId/createdAt`)

## Running Locally

```bash
node index.js
```

The API listens on `http://localhost:4000` by default.

Seeded users:

| Role | Email | Notes |
| ---- | ----- | ----- |
| Client | `client@example.com` | Requires OTP verification |
| Freelancer | `freelancer@example.com` | Requires OTP verification |
| Admin | `admin@example.com` | Requires OTP verification |

Use the OTP returned by `POST /auth/login` during local testing.

## Request Overview

| Endpoint | Description |
| -------- | ----------- |
| `POST /auth/login` | Request OTP (rate-limited) |
| `POST /auth/verify-otp` | Verify OTP and receive tokens |
| `POST /auth/refresh` | Refresh access token |
| `GET /jobs` | Paginated job listing with filters |
| `POST /jobs` | Create new job (client only) |
| `PATCH /jobs/:jobId/status` | Controlled status transitions |
| `POST /bids` | Submit bid (freelancer only) |
| `GET /chat/:jobId/messages` | Paginated chat history |
| `POST /chat/:jobId/messages` | Post chat message with optional base64 attachment |
| `WebSocket /chat/:jobId` | Real-time messaging + typing events |
| `POST /payments/escrow` | Move funds into escrow (client only) |
| `POST /payments/release` | Release escrow (requires `Idempotency-Key`) |
| `POST /webhooks/billplz` | Escrow/release webhook ingestion |
| `POST /webhooks/stripe` | Escrow/release webhook ingestion |
| `GET /wallet/transactions` | Paginated wallet history |
| `GET /notifications` | Paginated notification feed with category filter |
| `POST /reviews` | Submit review after job completion |
| `GET /healthz` | Liveness probe |
| `GET /readyz` | Readiness probe |

All responses append a `requestId` (and `X-Request-Id` header) to aid log correlation.

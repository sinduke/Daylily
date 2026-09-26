# 0024 Release and Operational Readiness

Status: implemented

Goal:

- Publish alpha.2, bound server operations, observe actual transfers, validate a reverse-proxy deployment, and measure repeatable contract/application changes.

Tasks:

- 0024-001: Publish and verify alpha.2 from the completed reliability candidate.
- 0024-002: Request-header/upload deadlines and bounded graceful shutdown.
- 0024-003: Response transfer completion, cancellation, and failure observation.
- 0024-004: API/SSE deployment trial with reverse proxy, restart, slow peers, and sustained traffic.
- 0024-005: OpenAPI compatibility and repeated AI application-change regression.
- 0024-006: Integrated documentation, review, and exact candidate validation.

Delivery:

- User authorized all five priorities in order. Independent preparation proceeds concurrently; alpha.2 contains the previously validated reliability work, and subsequent runtime changes remain a new iteration.
- Main stays the shared integration branch. Explicit file ownership prevents concurrent edits to the transport.
- Record actual duration, environment, and limits for deployment and AI trials; do not claim production certification or general model success rates.

Non-goals:

- Native TLS/HTTP2, ORM, a managed authentication stack, or paid infrastructure provisioning.

Validation:

- Published alpha.2 at f0d5342 passed ten exact-tag macOS/Linux jobs in run 36212096436.
- Operational candidate 3bad369 passed all nine jobs in run 36212918755; both platforms ran 65 Swift tests and 29 compatibility checks, plus external consumers and actual generated-client HTTP regressions.
- Local Linux/Caddy trial: 300.073 seconds, 31,382 requests, zero failures and clean scoped teardown. Clean Linux amd64 CI trial: 30.023 seconds, 3,940 requests, zero failures.
- Six actual AI edits across three fixed tasks passed immutable acceptance; incomplete baselines fail. These narrow open-test trials are not a general benchmark.
- Operational APIs remain unreleased after alpha.2. See `docs/operational-trial-results.md` for source boundaries and evidence.

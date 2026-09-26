# 0026-001 Persistent Commerce

Status: implemented
Epic: 0026-real-business-and-sustained-operation

Goal:

- Exercise Daylily with a real PostgreSQL business consumer, including persistence, concurrent writes, dependency outages and recovery.

Scope:

- An independent package under `examples/commerce-api/persistent` using application-owned PostgresNIO connection pooling and the existing commerce DTOs.
- Database-backed product/order routes, explicit readiness, bounded operations, idempotent order creation and lifecycle cleanup.
- Container build and automated HTTP restart/concurrency/failure/recovery validation.

Non-goals:

- Framework database APIs, ORM, production authentication, inventory reservation, durable SSE history, or a hosted production service.
- Replacing the existing in-memory commerce consumer or its release compatibility checks.

Steps:

- [x] 0026-001.1 Define application configuration, schema, repository and resource lifecycle.
- [x] 0026-001.2 Add persistent business routes, readiness and bounded SSE diagnostics.
- [x] 0026-001.3 Verify invalid inputs, concurrent/idempotent writes, application restart and database failure/recovery.
- [x] 0026-001.4 Provide container entry point, documentation and evidence for integration.

Architecture impact:

- PostgreSQL remains exclusively an example dependency. Core and the existing example keep their dependency graphs.

Public API impact:

- None in Daylily. The independent consumer owns its repository and operational configuration.

AIDEV updates required:

- Parent integration updates project map, commands, registry and release evidence.

Validation:

- `swift build --package-path examples/commerce-api/persistent --scratch-path /tmp/daylily-alpha4-persistence-build --jobs 3`: exit 0, macOS arm64 / Swift 6.3.2.
- `swift test` with the same package/scratch/jobs: exit 0, 2 tests passed.
- `python3 scripts/persistent-commerce-smoke-test.py --binary /tmp/daylily-alpha4-persistence-build/debug/PersistentCommerce --artifacts /tmp/daylily-alpha4-persistent-native-smoke-3`: exit 0, 13 real HTTP/PostgreSQL checks passed in 31.2865 seconds. Two replicas, 48 distinct concurrent creates, 32 concurrent idempotent attempts, 51 final orders, 1.5128-second database blackhole timeout, startup failure cleanup and zero remaining DB connections.
- Small result records, including the initial failed harness attempt, are preserved under `examples/commerce-api/persistent/validation/`. Full process/database logs remain in the evidence directory.
- `scripts/example-smoke-test.sh --mode path --workdir /tmp/daylily-alpha4-commerce-legacy-bounded --keep`: exit 0; original application build, 4 tests and `App --check` passed. A temporary Swift wrapper constrained all build/test calls to 3 jobs; source/scripts were unchanged for that constraint.
- Parent shared AIDEV updates are complete. Exact-revision CI and Docker/Linux integrated acceptance are tracked in 0026-006.

Notes:

- Driver API verified against official PostgresNIO README and `PostgresClient` source; selected stable version 1.33.1.
- Private Docker PostgreSQL uses explicit TLS disable; application defaults to certificate-verified TLS for other deployments.
- The first native harness attempt failed because Docker reassigned a dynamically published DB port on restart. The runner now pins its selected port; subsequent runs passed. This was a test endpoint configuration fault, not claimed as an application recovery failure fix.
- Implementation and local acceptance are complete; final integrated candidate verification is tracked separately in 0026-006.
- Independent review reproduced an idempotency/catalog race: a retry could read an empty existing-order result, then reject stock changed after the original committed. The fix reserves and locks the full key row before any existing-order/catalog reads, with no application hash collision behavior. Failed transactions roll back key reservations.
- A new deterministic two-real-HTTP-process PostgreSQL response-gating regression (`validation/idempotency-race.py`) exited 1 against a temporary build with only the key-lock change removed (201/400/201), and exited 0 against the fixed build (201/201/201, identical order snapshot, one DB row). Both small result records are preserved under `validation/`.
- Final post-fix real HTTP acceptance: `/tmp/daylily-alpha4-persistent-native-smoke-5`, exit 0, 13 checks in 31.1922 seconds, 51 orders/51 key rows, failed-order key rollback, and clean resource shutdown. Docker/Linux must rebuild with this fix before final acceptance.

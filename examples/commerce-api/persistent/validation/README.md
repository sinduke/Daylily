# Local persistence validation

`native-smoke.json` records the completed macOS arm64 / Swift 6.3.2 HTTP run with
two native application processes and PostgreSQL 17 in Docker: 13 checks passed,
51 committed orders and 51 key rows, a bounded database blackhole deadline, restart/recovery,
SSE cancellation, and zero application database connections after shutdown.
The final run also checks that failed orders leave no reserved key rows. The
separate Swift Testing suite passed 2 configuration/input-bound checks.
The original commerce path smoke also passed its build, 4 tests and `App --check`;
the preexisting in-memory application remains unchanged.

These are development-checkout results: `sourceRevision` is the last committed
base and `sourceDirty: true` explicitly identifies the uncommitted candidate.
They do not claim exact-tag or Linux verification. Final integrated revision and
external deployment evidence are recorded by the parent acceptance task.

`native-smoke-initial-failure.json` preserves the first harness failure. Its
database used an automatically assigned Docker host port; Docker changed that
port after stop/start, so the native client's configured endpoint became stale.
The runner now selects and pins a free host port before creating PostgreSQL.
The application required no change for that failure. A subsequent 12-check run
passed; the final recorded run also adds startup-failure cleanup acceptance.

Reproduce from the repository root:

```sh
swift build --package-path examples/commerce-api/persistent --jobs 3
python3 scripts/persistent-commerce-smoke-test.py \
  --binary examples/commerce-api/persistent/.build/debug/PersistentCommerce \
  --artifacts /tmp/commerce-native-evidence
```

The Docker version of this command omits `--binary`. The short test validates
behavior only; it does not measure sustained capacity or prove leak freedom.

## Concurrent idempotency/catalog regression

Review identified a gap between the empty existing-order lookup and subsequent
catalog validation. If another request committed the same key and the catalog
then changed, a retry could incorrectly return 400 before reaching INSERT's unique
key conflict handling. A later retry returned the successful original order.

`idempotency-race.py` controls that interleaving using two real HTTP application
processes and an isolated PostgreSQL database. A test-only trigger holds the first
order before commit; a loopback PostgreSQL proxy gates the retry's lookup reply.
After the first request commits, the runner changes stock/price and releases the
retry. The proxy does not change any SQL or payload data.

`idempotency-race-before.json` records the same regression script against a
temporary build with the key-table reservation/locking change removed: first
request 201, concurrent retry 400, later replay 201, one committed order. The script
correctly exited 1. `idempotency-race-after.json` records the fixed build: all three
requests return the same 201 order and original price, with one row. The retry
cannot reach its initial lookup until the first transaction commits.

```sh
python3 examples/commerce-api/persistent/validation/idempotency-race.py \
  --binary examples/commerce-api/persistent/.build/debug/PersistentCommerce \
  --artifacts /tmp/commerce-idempotency-race
```

This regression runs a native binary on macOS or Linux with Docker PostgreSQL.
It owns and removes only its uniquely named database container and application
processes. Full-key row locks, released with the transaction, avoid application
hash collisions and keep the whole check/create/replay operation serialized.

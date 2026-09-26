# Persistent commerce consumer

This independent SwiftPM application reuses the original commerce DTOs and adds a
real PostgreSQL repository. The parent `App` remains the small in-memory example;
neither its manifest nor Daylily's dependency graph gains a database dependency.

The application pins [PostgresNIO](https://github.com/vapor/postgres-nio) 1.33.1.
`PostgresClient` owns a bounded connection pool, registered as an application
repository dependency. An application-owned `ServiceGroup` starts the pool and
HTTP service; graceful shutdown drains HTTP before stopping the pool. Daylily
boot hooks initialize the example schema before binding the listener. Concurrent
replicas serialize schema setup with a PostgreSQL advisory transaction lock.

## Run

From the repository root, against an existing PostgreSQL database:

```sh
PGHOST=127.0.0.1 PGUSER=commerce PGDATABASE=commerce PGSSLMODE=disable \
  swift run --package-path examples/commerce-api/persistent PersistentCommerce
```

Supply `PGPASSWORD` through the environment when required by the server. The
example command disables TLS for a local database; the application default is
`verify-full`, requiring a trusted server certificate. Only `disable` and
`verify-full` are accepted. HTTP defaults to loopback and port 8080.

Container build and isolated Docker networking:

```sh
docker build -f examples/commerce-api/persistent/Dockerfile \
  -t daylily-persistent-commerce .
docker network create commerce-local
docker run -d --name commerce-db --network commerce-local \
  -e POSTGRES_USER=commerce -e POSTGRES_PASSWORD=local-only \
  -e POSTGRES_DB=commerce postgres:17
docker run --rm --name commerce-app --network commerce-local \
  -p 127.0.0.1:8080:8080 -e PGHOST=commerce-db -e PGUSER=commerce \
  -e PGPASSWORD=local-only -e PGDATABASE=commerce -e PGSSLMODE=disable \
  daylily-persistent-commerce
```

The container binds `0.0.0.0:8080` and runs as UID 65532. The resolved SwiftPM pins
are included at `/usr/local/share/daylily/Package.resolved`. Remove the example
database container with `docker rm -f -v commerce-db`, then remove the network
with `docker network rm commerce-local` after stopping the application.

| Setting | Default | Meaning |
| --- | --- | --- |
| `PGHOST`, `PGPORT` | `127.0.0.1`, `5432` | PostgreSQL endpoint |
| `PGUSER`, `PGDATABASE` | `commerce`, `commerce` | PostgreSQL account/database |
| `PGPASSWORD` | absent | Optional PostgreSQL password; never printed |
| `PGSSLMODE` | `verify-full` | Explicit `disable` for isolated test networking |
| `PGPOOL_MAX_CONNECTIONS` | `8` | Per-process pool maximum, accepted range 1–64 |
| `DB_OPERATION_TIMEOUT_MS` | `4000` | Whole-operation deadline, including waiting for a pool slot; 100–30000 |
| `HOST`, `PORT` | `127.0.0.1`, `8080` | Listener; Docker overrides HOST |
| `INSTANCE_ID` | `local` | Instance label in diagnostics |
| `SHUTDOWN_GRACE_MS` | `5000` | HTTP drain interval; 0–60000 |

## HTTP contract

- `GET /api/health`: process liveness, independent of the database.
- `GET /api/ready`: database connectivity; 200 when available, 503 during outage.
- `GET /api/products[?category=tea]` and `GET /api/products/:id`: persistent catalog.
- `POST /api/orders`: transactional creation, 201 with the existing `Order` DTO.
- `GET /api/orders/:id`: committed order snapshot, surviving process/database restarts.
- `GET /api/events?count=3&delay_ms=20`: bounded SSE diagnostic with `progress`
  events, numeric IDs, and `INSTANCE_ID:index` data. This is not an order event log.
- `GET /api/metrics`: constant-space counters for `activeRequests`, `activeStreams`,
  `completedRequests`, and response transfer `completed`, `cancelled`, `failed`.
  Handler counts exclude streaming lifetime; the metrics request itself counts as
  one active request. Transfer delivery is asynchronous, so totals may lag.

```sh
curl -H 'content-type: application/json' -H 'Idempotency-Key: order-demo-1' \
  --data '{"customerEmail":"orders@example.com","items":[{"productID":1,"quantity":2},{"productID":3,"quantity":1}]}' \
  http://127.0.0.1:8080/api/orders
```

Seeded products are IDs 1 (1299 cents), 2 (1899), 3 (2500), and 4 (4200, out of
stock). The request above totals 5098 cents. IDs use a database sequence starting
at 1001; failed or duplicate attempts may leave gaps, and order is not a promise
about response completion order.

`Idempotency-Key` is optional for compatibility with the original example. Use it
when retrying writes: an exact-text key row is locked for the whole transaction,
before reading either existing orders or the product catalog. This prevents a
retry from observing an empty lookup, then rejecting a catalog change that happened
after the original order committed. Simultaneous identical requests across replicas create one
order and return the same committed snapshot; reusing the key for a different
request returns 409. Replaying a successful request preserves its original price
and availability snapshot even after the catalog changes. Keys are 1–128 visible
ASCII bytes and are retained indefinitely in this example. The separate key table
uses the full text primary key, with no application hash or collision handling;
new key reservations roll back with failed transactions. Without a key, retrying
after a lost response can create a second order. A database error or timeout can
make the commit outcome uncertain; retries should retain the original key.

Creation validates at most 100 lines, positive product IDs, quantities 1–10000,
a nonempty customer identifier up to 320 UTF-8 bytes, and a 32 KiB JSON body.
It verifies availability, snapshots prices under transaction-held shared locks,
checks arithmetic overflow, and commits one order atomically. It does not reserve
or decrement stock. Seed initialization never overwrites existing product rows.

## Failure and cleanup behavior

The database starts before the HTTP service; an initial migration failure exits
startup and joins the pool task. During operation, pool connection attempts have
a 2-second timeout and server-side statement/lock limits provide a second bound.
An application deadline includes pool waiting and query execution. Cancellation
closes the leased connection so a stalled network does not leave a detached query
or timeout task. Operational database errors return only `Database temporarily
unavailable` with status 503. The pool reconnects after recovery, without restarting
the application. Liveness and bounded diagnostic SSE remain independent of DB health.

SIGTERM/SIGINT reach the outer ServiceGroup, which drains HTTP while the pool is
still usable, then closes the pool. `LIFECYCLE` records identify started, shutdown,
cleanup and pool closure; credentials, SQL and customer bodies are never logged.

This is an initial-schema example, not an upgrade migration engine. It has no
authentication or inventory reservation and should remain on a private network.
Public routing, certificate management and authentication are deployment/app
responsibilities. No framework database module, ORM or managed-service API is added.

## Verify

```sh
swift test --package-path examples/commerce-api/persistent --jobs 3
python3 scripts/persistent-commerce-smoke-test.py --artifacts /tmp/commerce-evidence
```

The smoke builds the image and starts two replicas plus PostgreSQL. It checks
bound parameters, invalid input and rollback, 48 distinct concurrent writes, 32
concurrent idempotent attempts, process restart, a paused database network blackhole,
database stop/start, bounded 503 responses, recovery, SSE cancellation and zero
remaining application database connections after graceful shutdown, plus nonzero
startup failure with joined resources. It owns only
uniquely named containers/network and removes them in `finally`; output evidence
is retained on success or failure. Use `--image IMAGE --skip-build` for a prebuilt
image, or `--binary /absolute/path/PersistentCommerce` for native HTTP checks
against Docker PostgreSQL. Evidence directories must not already exist.

The sustained deployment runner is a separate acceptance layer; this short smoke
does not establish capacity, leak freedom, or production readiness.

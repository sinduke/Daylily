# Alpha.4 candidate: real business and sustained operation

The latest published version remains `0.1.0-alpha.3`. This guide describes the current **unreleased alpha.4 candidate**. Execution and evidence are tracked in [epic 0026](../ai/epics/0026-real-business-and-sustained-operation.md). Do not use these added APIs against the alpha.3 tag.

## Bounded transport resources

```swift
let configuration = ServerConfiguration(
    responseWriteTimeout: .seconds(30),
    responseObserverCapacity: 64
)
```

`responseWriteTimeout` is a positive duration or `nil` to disable. A separate deadline covers each pending response head, body chunk and end write/flush. Waiting in a handler or between SSE producer writes does not start this timer. A write deadline records `.failed` before cancelling the producer and closing its connection. It cannot forcibly terminate non-cooperative application code.

`responseObserverCapacity` must be positive; its default is 64. One admission gate is shared by every connection of a `NIOHTTPServer` instance. Admission happens synchronously before creating the delivery task. When all slots are occupied, the new event is dropped immediately: there is no hidden queue or task waiting for capacity. Callbacks can overlap and arrive out of order. A returning callback releases its slot. An indefinitely suspended callback occupies one slot but does not block a request or shutdown. Total event retention and durable export remain application responsibilities; the in-memory observer still retains all delivered events.

`NIOHTTPServer.responseObserverSnapshot` returns the Core-owned `ResponseTransferDeliverySnapshot` with `capacity`, `inFlight`, `completedEvents` and `droppedEvents`; it is `nil` without an observer. The counters describe delivery, not HTTP success. Use explicit server composition when the application needs this snapshot; `Application.run` and ServiceLifecycle forward the same configuration but do not expose the server object. No observer means no delivery task.

## Persistent commerce consumer

[Persistent commerce](../examples/commerce-api/persistent/README.md) is a separate application package. It reuses the existing commerce DTOs and owns a pinned PostgresNIO client/pool, environment configuration, migrations, transaction boundaries and ServiceGroup lifecycle. The framework gains no database dependency. The original in-memory commerce example remains available.

The example supports concurrent orders and an optional idempotency key, restart persistence, database readiness, bounded API bodies, bounded progress SSE and constant-space metrics. Health is independent of database readiness. Database failure produces an application-owned public 503 response; recovery does not require restarting the application. It is a private operational example, with no authentication layer or durable SSE replay guarantee.

```sh
# macOS/Linux Swift package consumption; no running database required
scripts/persistent-consumer-smoke-test.sh --mode path

# Actual PostgreSQL and HTTP behavior; see --help for native binary options
python3 scripts/persistent-commerce-smoke-test.py --help

# Container API/SSE/database trial behind verified local-CA TLS
python3 scripts/sustained-deployment-trial.py \
  --duration 3600 --artifacts /new/empty/daylily-business
```

The external run uses a GitHub-hosted Linux machine, private ephemeral containers and loopback-only host ports. Caddy terminates TLS using its local CA; the client trusts that specific CA and verifies the hostname. This is not a persistent public endpoint. Database TLS is disabled only inside the isolated trial network. Every run owns unique resource names and cleans only those resources.

The one-hour acceptance run records resource time series, source revision/dirty state, images, dependency pins, proxy configuration, fault timing and cleanup. Planned database 503s are distinct from unexpected traffic failures. RSS, FD and active stream checks use explicit budgets and do not prove leak freedom or peak capacity. A 24-hour soak remains a later Beta gate.

## Nullable API contracts

```swift
let note = OpenAPISchema.object(
    properties: ["text": .string().nullable()],
    required: ["text"]
)
```

`nullable()` returns a copy accepting null in addition to a concrete type and exports OpenAPI 3.1 `type: [T, "null"]`. `isNullable` reports the concrete type/enum intersection; it does not resolve references. Required presence and nullability are independent: the example requires the property but allows its value to be null. An optional property may be absent regardless of its value type.

Mark the component schema itself nullable before referencing it. Applying `nullable()` directly to a reference is rejected: adding a `$ref` sibling cannot widen the referred schema. General unions and `oneOf`/`anyOf`/`allOf` remain unsupported. The compatibility checker accepts one concrete type plus null and pure null, checks enum intersections, and retains the old-client to new-server direction. Unsupported constructs still return exit 2.

The current Swift OpenAPI Generator fixture uses inline nullable array elements because generator 1.13.1 loses nullable item semantics for the tested `$ref` array shape. Swift Codable optional values also merge absent and null; this feature does not provide a generic three-state PATCH value or guarantee every generated decoder enforces required-nullable presence. Real HTTP checks cover the supported generated shapes.

## Broader real AI edits

The opt-in [extended runner](../ai/evals/repeated-changes/run_extended.py) adds concurrent/idempotent inventory, durable file repository integration, and body-replay/outage repair. Each task spans source files. It validates incomplete baselines, withholds acceptance source until after the model turn, and records first-pass outcomes separately from bounded repair attempts.

The dependency is an immutable archive of the published alpha.3 commit. Read restrictions are audited in the transcript; the protocol is not a hermetic secrecy sandbox. CI runs baseline validation only and never starts account-consuming model edits. [Recorded actual trials](../ai/evals/repeated-changes/results/2026-09-26-alpha4/README.md) passed 6/6 on first attempts with no repairs; this is evidence for these fixtures, not a general AI success-rate claim.

## Validation state

Implementation/focused checks are recorded per task. Full candidate CI and the external one-hour deployment remain required until the execution checklist records their completed evidence. A new published tag is a separate release action.

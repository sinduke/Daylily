# 0026-002 Runtime Resource Bounds

Status: implemented
Epic: 0026-real-business-and-sustained-operation

Goal:

- Bound transport observation delivery and response write waits without timing out idle handlers or SSE producers.

Scope:

- Shared server-wide active observer capacity, drop-newest saturation, thread-safe delivery snapshot.
- A deadline for each pending response head/body/end write-and-flush operation.
- Real socket saturation, recovery, slow-reader, disabled-timeout and idle-stream regression tests.

Non-goals:

- Request concurrency admission, durable telemetry queues, observer export lifetime management, total handler or stream lifetime deadlines.

Steps:

- [x] 0026-002.1 Implement bounded observer delivery and public snapshot.
- [x] 0026-002.2 Implement response write deadline with exactly-once failed terminal state.
- [x] 0026-002.3 Verify resource saturation/recovery and socket deadlines.
- [x] 0026-002.4 Integrate shared AIDEV and hand full candidate CI verification to 0026-006.

Architecture impact:

- Core retains standard-library-only configuration and immutable snapshot values. NIO owns locks, task admission, write timers and transport state.

Public API impact:

- Append `responseWriteTimeout: Duration? = .seconds(30)` and `responseObserverCapacity: Int = 64` to both server configuration initializers; timeout is positive or nil, capacity is positive.
- Add Core `ResponseTransferDeliverySnapshot` with `capacity`, `inFlight`, `completedEvents`, `droppedEvents` and public memberwise initializer.
- Add `NIOHTTPServer.responseObserverSnapshot: ResponseTransferDeliverySnapshot?`; nil with no observer. Counters and capacity are shared across connections, server value copies and runs of the same instance.
- Observer saturation drops the newest event immediately, without queuing or spawning a task. Shutdown never awaits observer callbacks. A blocked callback retains one of the fixed slots until it returns.
- Response write timeout covers a pending write-and-flush promise only, not handler execution or producer idle time. Expiry records failed, cancels the producer cooperatively and closes the connection without a second HTTP response.

AIDEV updates required:

- Parent owns api-registry/runtime-contracts/architecture/invariants/registry and consumer documentation integration.

Validation:

- macOS Swift 6.3.2: `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test --scratch-path /tmp/daylily-alpha4-bounds-build --jobs 2 --filter 'ResourceBoundTests|ServerOperationTests|ResponseTransferObserverTests|ResponseStreamingTests'` exited 0: 41 tests across four suites passed, including six new resource-bound tests. Log: `/tmp/daylily-alpha4-bounds-tests-final.log`.
- Verified 40 independent TCP connections share two observation slots: two blocked callbacks, 38 dropped events, zero queued deliveries; releasing both callbacks frees the slots and the next request is delivered.
- Verified saturated observer shutdown returns while its one admitted callback remains suspended; no extra callbacks are started.
- Verified a non-reading peer expires a 100 ms pending write, cooperatively cancels the producer and yields exactly one failed transfer. With the timeout disabled, the same producer remains blocked beyond 350 ms until client disconnect, which yields cancelled.
- Verified a 150 ms handler wait plus two 150 ms SSE idle intervals survive a 50 ms write deadline and produce a completed transfer.
- Existing streaming, cancellation, HTTP framing, inbound deadlines, graceful drain and transfer observability regressions passed. Compilation produced no warnings; the existing non-Sendable response-end context capture now uses the loop-bound context.
- First focused run found a test fixture mismatch (`write(String)` sends raw bytes, while the assertion expected SSE encoding). Replaced fixture writes with `ServerSentEvent`; the complete final focused run passed. First log retained at `/tmp/daylily-alpha4-bounds-tests.log`.
- Parent synchronized shared AIDEV/API/registry/candidate documentation and extended the external current consumer. Full local build, 74 tests, behavior checks and current external consumer passed. Independent review found no blocking timer/admission issue. Final macOS/Linux CI is tracked by 0026-006.

Notes:

- Event retention inside application observers remains application-owned; the runtime bounds delivery tasks, not a collector's storage.

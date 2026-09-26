# 0024-002 Request Deadlines and Shutdown Drain

Status: implemented
Epic: 0024-release-and-operational-readiness

Goal:

- Bound stalled request reads and allow active responses to finish during normal shutdown without applying an overall lifetime limit to SSE.

Scope:

- Add configurable request-header, upload-idle, and shutdown-grace durations.
- Start header deadlines while waiting for a complete header, including partial headers; stop upload deadlines on request end and suspend them during server read backpressure.
- Stop accepting connections and new pipelined work during graceful shutdown; close remaining connections at the grace deadline.
- Preserve immediate forced shutdown on Swift task cancellation and safe callback admission after transport teardown.
- Integrate the separately owned response-transfer observer hook at transport termination.

Non-goals:

- Handler execution deadlines, outbound write-stall deadlines, TLS, or HTTP/2.
- Forced termination of user tasks or lifecycle hooks that ignore cooperative cancellation.
- Durable delivery of telemetry to arbitrary sinks.

Steps:

- [x] 0024-002.1 Add NIO-free Duration configuration and transport bridging.
- [x] 0024-002.2 Implement request-header and upload-idle deadlines with backpressure awareness.
- [x] 0024-002.3 Coordinate graceful connection quiescing, deadline closure, and immediate force cancellation.
- [x] 0024-002.4 Integrate exactly-once response terminal events without blocking event loops.
- [x] 0024-002.5 Validate real sockets, SSE, stalled reads, backpressure, and concurrent shutdown.
- [x] 0024-002.6 Complete shared documentation and integration review with the parent agent.

Architecture impact:

- Public Duration settings live in DaylilyCore; timers, connection registry, and NIO quiescing remain private to DaylilyNIO.
- A synchronous callback gate remains the only admission path from Swift tasks to a connection's event loop.
- NIO's HTTP pipeline owns quiescing of idle connections and pending pipelined requests.

Public API impact:

- ServerConfiguration and NIOServerConfiguration gain requestHeaderTimeout: Duration? (default 15 seconds), uploadIdleTimeout: Duration? (default 30 seconds), and shutdownGracePeriod: Duration? (default 10 seconds).
- nil disables the corresponding deadline. A nil grace period waits for active connections indefinitely until force cancellation; zero grace closes immediately.
- Header/upload durations must be positive; grace periods must be nonnegative.
- NIOHTTPServer accepts the separately defined optional ResponseTransferObserver via its initializer; the parent integrates Application and ServiceLifecycle entry points.

AIDEV updates required:

- The parent owns shared API registry, runtime contracts, configuration docs, release notes, and registry updates.

Validation:

- Final `swift test --filter 'ServerOperationTests|ResponseStreamingTests|ResponseTransferObserverTests'` passed all 35 tests in three suites (2026-09-26), including the complete existing streaming suite. Local evidence: `/tmp/daylily-operation-final-tests.log`.
- Real-socket checks cover idle/partial headers, disabled header deadlines, stalled uploads returning 408 and releasing body readers, completed-request SSE, two-megabyte upload backpressure, concurrent shutdown signals, idle closure, dropped queued pipeline work, graceful SSE deadlines, and force cancellation of unlimited drain.
- Transfer checks cover separation from handler logging, flushed payload counts, transfer duration and request metadata, producer failure, immediate terminal cancellation despite noncooperative producers, no duplicate late terminal event, and slow observer isolation.
- The final test output contained no stopped-event-loop scheduling warnings, errors, or test issues. Initial local linker debug-symbol warnings referenced missing cached PCM files; compilation and tests succeeded.
- Independent review fixed two deadline boundaries: an early streaming response cancels the abandoned upload deadline, and the next header budget begins only after the previous response's end framing flushes. The final focused run covers early SSE lasting beyond the abandoned upload deadline and confirms a successfully drained response reports `completed`.
- A second reviewer checked the connection registry, callback gate, observer arbitration, and upstream NIO quiescing behavior; no further concrete issue remained.
- The parent coordinates whole-package build/test and external-consumer validation.

Notes:

- Header timeout also bounds an idle connection awaiting its next request; it is inactive while a response is being produced.
- The next header budget starts after the response end write succeeds; it does not charge response framing backpressure to the next request.
- The upload idle budget restarts after server backpressure is released rather than charging the client for the server's pause.
- An early response abandons the unread upload and closes its connection after the response; the abandoned upload's deadline no longer applies to response production.
- A shutdown deadline bounds transport resources, not arbitrary application cleanup or a noncooperative user's task lifetime.

Integration evidence:

- Shared AIDEV API/runtime/map/registry and user guides are synchronized. Local full build, 65 tests and behavior checks passed; default server HTTP/SIGTERM passed.
- The 300-second Linux/Caddy deployment passed 31,382 requests with no failures and clean teardown. See `docs/operational-trial-results.md`.
- Exact-candidate cross-platform CI is tracked separately by 0024-006; this task status records implemented and locally validated scope.

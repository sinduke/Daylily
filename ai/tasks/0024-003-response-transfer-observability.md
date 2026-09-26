# 0024-003 Response Transfer Observability

Status: implemented
Epic: 0024-release-and-operational-readiness

Goal:

- Distinguish handler response-production latency from actual response transmission.
- Observe one terminal transfer event, including streamed responses and cancellation.
- Preserve the transport-free core and optional logging backend ownership.

Scope:

- Core `ResponseTransferEvent`, `ResponseTransferOutcome`, and `ResponseTransferObserver`.
- Optional NIO observer and public application/server lifecycle entry-point wiring.
- Event-loop-owned terminal arbitration and successfully flushed body-byte accounting.
- In-memory/console observers and application-owned SwiftLog adapter.
- Focused adapter tests plus real-socket terminal-state and slow-observer checks.

Non-goals:

- Mandatory instrumentation, metrics/tracing backends, or global logger bootstrap.
- Peer acknowledgment of application consumption, header/framing byte accounting.
- Guaranteed durable event delivery after process exit or forcing uncooperative sinks to stop.

Steps:

- [x] 0024-003.1 Define immutable core event/protocol and delivery semantics.
- [x] 0024-003.2 Add optional console, in-memory, and SwiftLog adapters.
- [x] 0024-003.3 Integrate exactly-once terminal arbitration in NIO and public entry points.
- [x] 0024-003.4 Verify adapter metadata, actual transfer completion/failure/cancellation, and observer isolation.
- [x] 0024-003.5 Integrate AIDEV/public docs and complete shared validation.

Architecture impact:

- Core introduces no imports or dependencies; observation values/protocol contain no NIO types.
- NIO owns transport state and optional observer delivery; it does not depend on observability/logging modules.
- DaylilyObservability implements small collector/console adapters.
- DaylilySwiftLog consumes the core protocol and an application-owned `Logger`.
- `ServerConfiguration` retains `Equatable`; observers are separate optional constructor/run arguments.

Public API impact:

- `ResponseTransferOutcome: String, Equatable, Sendable`: completed, cancelled, failed.
- `ResponseTransferEvent: Equatable, Sendable` with optional method/path/requestID/correlationID; status; body bytesSent; durationNanoseconds; outcome.
- `ResponseTransferObserver: Sendable` with nonthrowing `record(_:) async`.
- `InMemoryResponseTransferObserver` actor (`record`, `snapshot`) and `ConsoleResponseTransferObserver`.
- `SwiftLogResponseTransferObserver(logger:)` and `init(label:)`.
- Public server/application lifecycle entry points accept `responseObserver: (any ResponseTransferObserver)? = nil`.

Delivery contract:

- The event records transmission start through terminal state, excluding handler production time and observer execution time.
- `bytesSent` counts successfully completed body write/flush operations; headers/framing are excluded and peer consumption is not guaranteed.
- `completed` concerns the transfer, so a fully sent HTTP 500 still has completed outcome.
- The transport arbitrates terminal state exactly once on its event loop, including disconnect while a producer ignores cancellation; late producer completion cannot report again.
- Frozen events are delivered from a Swift task that awaits nonthrowing `observer.record`; observer code does not run on the event loop.
- Different responses may report concurrently/out of order. Server shutdown does not wait indefinitely for sinks; generation is exactly once, durable delivery on process exit is application-owned.
- A nil observer is the default and creates no observation-delivery task.
- SwiftLog uses `daylily.response.transfer_duration_ns`, distinct from request logging's handler `daylily.duration_ns`, and includes outcome/body bytes/request metadata.

AIDEV updates required:

- Parent integration owns API registry, runtime contracts, module dependency map, registry.yml, and user-facing deployment/streaming docs.
- Document best-effort delivery separately from terminal-state generation and expose application-owned exporter lifetime guidance.

Validation:

- Agent runs isolated adapter tests without contending for the root SwiftPM build directory.
- Transport owner adds real-socket coverage and coordinates full `swift test` with the parent.
- Parent runs full build/test/check and external consumer validation after integration.
- `git diff --check`.

Validation results:

- 2026-09-26: independent SwiftPM path consumer passed all three `ResponseTransferObserverTests` on Apple Swift 6.3.2 / Xcode 26.5. Coverage includes concurrent collector delivery, SwiftLog outcome levels and metadata, distinct transfer/handler duration keys, and absent request context for protocol errors.
- 2026-09-26: inspected transport integration and public entry-point wiring. NIO owns terminal arbitration, freezes successful write/flush body accounting, handles disconnected producers, and dispatches the nonthrowing sink outside its event loop. Both `Application.run` overloads and the ServiceLifecycle initializer/helper forward the optional observer.
- 2026-09-26: `git diff --check` passed. Final transport arbitration and adapter tests passed with the 35-test focused run; shared documentation is synchronized.

Notes:

- NIO/server configuration integration is owned by the streaming agent; root owns application/ServiceLifecycle entry points and Package.swift.
- No commit/push in this delegated slice.

Integration evidence:

- Shared AIDEV API/runtime/map/registry and user guides are synchronized. Local full build, 65 tests and behavior checks passed; default server HTTP/SIGTERM passed.
- The 300-second Linux/Caddy deployment passed 31,382 requests with no failures and clean teardown. See `docs/operational-trial-results.md`.
- Exact-candidate cross-platform CI is tracked separately by 0024-006; this task status records implemented and locally validated scope.

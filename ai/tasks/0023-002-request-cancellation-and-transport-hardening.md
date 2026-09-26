# 0023-002 Request Cancellation and Transport Hardening

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Make request body waits, handler tasks, and transport resources terminate reliably.

Scope:

- Cancel the request handler and response producer on client disconnect.
- Make body reader and producer waits respond to Swift task cancellation.
- Release the event loop group when server bind fails.
- Add focused cancellation and socket integration tests.

Non-goals:

- Forced termination of user tasks that ignore cooperative cancellation.
- New HTTP versions, TLS, or changes to application service ownership.

Steps:

- [x] 0023-002.1 Track handler and response tasks per connection and cancel them on disconnect.
- [x] 0023-002.2 Release body reader/writer continuations on task cancellation.
- [x] 0023-002.3 Release the event loop group on bind failure.
- [x] 0023-002.4 Add cancellation and occupied-port network regression tests.
- [x] 0023-002.5 Complete focused validation, including server shutdown with active handler and producer tasks.
- [x] 0023-002.6 Synchronize shared AIDEV documentation and complete local integration review.
- [x] 0023-002.7 Prevent late task completions from scheduling work on stopped event loops.

Architecture impact:

- DaylilyNIO retains task handles and request IDs so stale completions cannot affect a later request.
- After request end, a single read upstream of NIO's pipelining handler observes an idle peer disconnect on Darwin while preserving ordered, bounded prefetch.
- All socket and NIO lifecycle details remain inside DaylilyNIO.
- A private `NIOLockedValueBox` gate serializes task callback admission with channel teardown. NIOConcurrencyHelpers remains a transport-only dependency; no public API or deployment target changes.

Public API impact:

- No new public API is required for cancellation.
- Buffered and streaming body reads respect Swift task cancellation.

AIDEV updates required:

- Shared runtime contracts, transport guarantees, registry, and roadmap updates are coordinated by the integrating agent.

Contracts:

- Explicit transport body cancellation still completes readers normally.
- Swift task cancellation terminates waiting body reads with CancellationError.
- Core and public APIs remain NIO-free.

Validation:

- Focused and full builds/tests coordinated by the root agent.
- `swift test --filter ResponseStreamingTests` passed all 19 tests on macOS with Swift 6.3.2; the suite includes real socket tests and parameterized cancellation cases. The final gate runs contain no stopped-event-loop scheduling warnings. Evidence: `/tmp/daylily-streaming-gate.log` and `/tmp/daylily-streaming-final.log`, run 2026-09-26 by the integrating agent.
- The integrating agent confirmed the complete 49-test package suite passes after the scheduling-gate fix with no stopped-event-loop warnings.
- Fixed the initial Darwin disconnect regression: NIO suppresses reads while waiting for a response, preventing EOF delivery to a suspended handler. The final run passed handler, upload-reader, response-producer, and whole-server cancellation checks.
- A subsequent full run revealed late `completeWithTask`/`makeFutureWithTask` callbacks after event-loop shutdown. Replaced those callbacks with synchronously gated scheduling and removed post-shutdown response-close scheduling. The server-stop regression now deliberately finishes handler and producer cleanup 30 ms after cancellation.

Notes:

- Explicit transport cancellation is normal body termination; task cancellation uses CancellationError.
- NIO asynchronous writes do not themselves respect task cancellation. Closing the channel on disconnect/failure unblocks outstanding write promises.
- Cancellation propagates when the transport observes closure. Deliberate read backpressure on a peer with unread input can delay EOF observation; the API does not promise forced termination or instantaneous peer detection.
- Shared AIDEV, local integration, and remote CI are complete. Task 0023-007 records all eight passing jobs at candidate `7d56798`.

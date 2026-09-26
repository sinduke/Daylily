# 0023-004 Response Streaming

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Deliver response bytes incrementally with awaited writes and cancellation propagation.

Scope:

- Add Daylily-owned ResponseBody and ResponseBodyWriter.
- Keep Response.body and bodyString as buffered compatibility views, backed by a single responseBody value.
- Add bounded async collection to testing helpers.
- Await each NIO write before accepting the next producer write.
- Preserve HEAD, 204, and 304 body/framing rules.
- Add a small ServerSentEvent value and Response.eventStream convenience.

Non-goals:

- File response helpers, compression, automatic reconnection, or SSE heartbeats.
- Swift type schema inference or new macro syntax.

Steps:

- [x] 0023-004.1 Add buffered and one-shot ResponseBody storage and an awaited writer.
- [x] 0023-004.2 Preserve existing buffered response APIs and add bounded testing helpers.
- [x] 0023-004.3 Stream NIO writes with exact framing and transport cancellation.
- [x] 0023-004.4 Add SSE values and incremental socket/backpressure/framing regressions.
- [x] 0023-004.5 Validate writer lifetime, network framing, pipelining, cancellation, and backpressure.
- [x] 0023-004.6 Synchronize shared AIDEV documentation and complete local integration review.
- [x] 0023-004.7 Gate asynchronous transport writes and completions against connection teardown.

Architecture impact:

- ResponseBody and ServerSentEvent depend only on the Swift standard library.
- The transport SPI consumes chunks through an awaited sink; no queue or transport type enters DaylilyCore.
- The NIO transport owns content length/chunking and closes after a producer fails once headers were sent.
- Response head/body/end writes use a private connection gate and checked continuations. Closed connections reject new scheduling; writes already admitted complete once through their NIO write result. Late producer cleanup never schedules into a stopped event loop.

Public API impact:

- ResponseBody.bytes([UInt8])
- ResponseBody.stream(length: Int? = nil, producer)
- ResponseBody.collect(upTo: ByteCount)
- ResponseBodyWriter.write(ByteChunk/[UInt8]/String) async throws
- Response.responseBody and Response.init(status:headers:body: ResponseBody)
- Response.eventStream(producer)
- ServerSentEvent(data:id:event:retry:) and ResponseBodyWriter.write(ServerSentEvent)
- Response.collectBody(upTo:), bodyString(upTo:), requireBody(_:upTo:), json(_:upTo:), and requireJSON(_:as:upTo:) in DaylilyTesting.

AIDEV updates required:

- Shared response/runtime contracts, API registry, feature state, examples, and roadmap updates are coordinated by the integrating agent.

Contracts:

- Streaming response producers are one-shot and demand-driven.
- Producers must await writes; no hidden unbounded queue is introduced.
- Buffered response compatibility views return empty bytes/string for streams; async collection is explicit and bounded.
- Producer failure after headers closes the connection without appending a second response.
- Suppressed response bodies do not start their producer.

Validation:

- Focused and full builds/tests coordinated by the root agent.
- Socket tests cover incremental delivery, framing, disconnect cancellation, and producer failures.
- `swift test --filter ResponseStreamingTests` passed all 19 tests on macOS with Swift 6.3.2. Final gate runs contain no stopped-event-loop scheduling warnings. Evidence: `/tmp/daylily-streaming-gate.log` and `/tmp/daylily-streaming-final.log`, run 2026-09-26 by the integrating agent.
- The integrating agent confirmed the complete 49-test package suite passes after the scheduling-gate fix with no stopped-event-loop warnings.
- Covered incremental SSE delivery, HEAD/204/304 suppression and explicit representation lengths, exact known-length framing and mismatches, producer failure, pipelined ordering, Connection close tokens, slow-reader backpressure, disconnects, and server shutdown.
- Deterministic writer tests cover concurrent calls, writes after producer completion, and a producer returning with an escaped write still in flight; aborted writes cannot later report successful completion.
- The whole-server regression delays canceled handler and producer completion by 30 ms, exercising response task cleanup after the underlying event loops have closed.
- `git diff --check` passed for the modified transport/core/testing files.

Notes:

- A stream's producer and its copies share one consumption token; buffered responses can still be inspected repeatedly.
- Test helpers reject synchronous stream decoding rather than silently asserting against an empty compatibility view.
- Shared AIDEV, local integration, and remote CI are complete. Task 0023-007 records all eight passing jobs at candidate `7d56798`.

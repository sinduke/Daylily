# Vapor 5 beta review — 2026-09-26

Vapor 5 beta.1 was released on September 15 and beta.2 on September 16. These are beta versions, not stable releases. This review informs Daylily's priorities; Daylily does not depend on Vapor.

## What the releases change

Vapor beta.1 includes request/response streaming, response-writer lifetime enforcement, removal of NIO types from response/content public APIs, application changes, HTTP/2, and TLS improvements. These reinforce the importance of streaming correctness and clear runtime boundaries. [Official beta.1 release](https://github.com/vapor/vapor/releases/tag/5.0.0-beta.1)

Beta.2 fixes SwiftPM dependency resolution and changes Foundation/HTTP Server dependencies. Package-consumer validation needs to exercise actual dependency resolution at a specific revision or version, not just a framework's own working tree. [Official beta.2 release](https://github.com/vapor/vapor/releases/tag/5.0.0-beta.2)

## Daylily after the current delivery

| Area | Current Daylily outcome | Remaining boundary |
| --- | --- | --- |
| Streams | Awaited response writes, request backpressure, SSE, writer lifetime checks, disconnect cancellation | Cancellation is cooperative; unread input can delay disconnect detection |
| Runtime boundary | Daylily-owned request/response APIs; NIO remains inside the transport | This is a shared architectural direction, not sufficient differentiation by itself |
| Lifecycle | Shared startup recovery, teardown once, original and aggregated errors | No request-draining deadline or forced task termination |
| Contracts | Explicit OpenAPI schema/security components, generated client/server HTTP round trip, fixed application-change exercises | Supported schema subset only; exercises are not a general AI success-rate benchmark |
| Transport deployment | HTTP/1.1 socket tests and macOS/Linux consumer matrix | No built-in TLS or HTTP/2; deployment behavior still needs application trials |

Implementation and compatibility details are in [Reliability and streaming](reliability-and-streaming.md); validation gates and supported environments are in [Release readiness](release-readiness.md).

## Recommended next sequence

These are follow-up recommendations, not additional work included in the current delivery:

1. **Bound server operations:** configurable upload/request deadlines, shutdown drain limits, and observations for stream completion/failure.
2. **Run a deployment trial:** SSE behind a reverse proxy, slow consumers, rolling restarts, and sustained operation. Use its requirements to decide whether native HTTP/2/TLS is necessary.
3. **Protect contract evolution:** schema change reports and generated-client compatibility regressions; expand nullable/composition support against real DTO needs.

The immediate gate remains a fully passing exact-candidate CI matrix before preparing a tagged alpha. Keep OpenAPI/runtime/macro contract consistency and reproducible application changes central to Daylily's positioning.

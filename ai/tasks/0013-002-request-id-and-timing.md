# 0013-002 Request ID And Timing

Status: implemented
Epic: 0013-observability-middleware

Goal:

- Add clear request correlation semantics to Daylily observability.
- Generate a Daylily-owned unique request ID for every request.
- Treat external `x-request-id` as correlation input, not as Daylily's unique request identity.
- Add request duration to request logs.

Scope:

- Add `Request.with(headers:)` in `DaylilyCore`.
- Add `RequestIDGenerator` in `DaylilyObservability`.
- Add a default request ID generator using `dl_<UUID>`.
- Add request ID header constants.
- Add `RequestIDMiddleware`.
- Add `Request.daylilyRequestID` helper.
- Add `Request.correlationID` helper.
- Extend `RequestLog` with:
  - `requestID: String?`
  - `correlationID: String?`
  - `durationNanoseconds: UInt64?`
  - `errorReason: String?`
- Update `RequestLoggingMiddleware` to record duration and IDs.
- Update `RequestLoggingMiddleware` to record public error reasons for `4xx` and `5xx` responses.
- Update `ConsoleRequestLogSink` output to include request ID, correlation ID, and duration when available.
- Add behavior checks.
- Update README and AIDEV docs.

Non-goals:

- Full `RequestContext`.
- OpenTelemetry.
- Trace/span model.
- Metrics backend.
- `Server-Timing` response header.
- ULID/KSUID dependency.
- Validation framework for external correlation IDs.
- Automatic outgoing client propagation.

Core semantic decision:

```text
requestID     = Daylily-generated ID, unique per request inside this service
correlationID = external correlation value read from x-request-id, not guaranteed unique
```

Header behavior:

```text
incoming has x-request-id:
  requestID = Daylily generated dl_<UUID>
  correlationID = incoming x-request-id
  response x-request-id = incoming x-request-id
  response x-daylily-request-id = requestID

incoming has no x-request-id:
  requestID = Daylily generated dl_<UUID>
  correlationID = nil for logging semantics
  downstream request x-request-id = requestID for compatibility
  response x-request-id = requestID
  response x-daylily-request-id = requestID
```

Target usage:

```swift
let app = Application {
    Get("/hello") { request in
        request.daylilyRequestID ?? "missing"
    }
}
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

Expected log shape:

```text
GET /hello -> 200 requestID=dl_... correlationID=client-abc duration=1.8ms
```

Rules:

- Daylily must not depend on externally supplied IDs for uniqueness.
- `x-request-id` is accepted for ecosystem compatibility, but Daylily treats it as correlation data.
- `x-daylily-request-id` is Daylily's explicit server-generated request ID header.
- `RequestIDMiddleware` must preserve method, path, body, parameters, and query.
- `Request.with(headers:)` must preserve the same one-shot body storage.
- `Request.daylilyRequestID` reads `x-daylily-request-id`.
- `Request.correlationID` reads `x-request-id`.
- In the no-incoming-header case, `Request.correlationID` may equal `Request.daylilyRequestID` downstream because `x-request-id` is populated for compatibility; `RequestLog.correlationID` should stay `nil` unless an external ID was present.
- `RequestLog` new fields should default to `nil` to preserve existing construction ergonomics.
- Timing is measured by `RequestLoggingMiddleware` around `next.respond(to:)`.
- Timing is stored as nanoseconds in the data model; sinks may format it as milliseconds.
- External correlation IDs are opaque and untrusted.

Steps:

- [x] 0013-002.1 Add `Request.with(headers:)`.
- [x] 0013-002.2 Add request ID generator and header constants.
- [x] 0013-002.3 Add `RequestIDMiddleware`.
- [x] 0013-002.4 Add request ID helper properties.
- [x] 0013-002.5 Extend `RequestLog` and request logging timing.
- [x] 0013-002.6 Add behavior checks.
- [x] 0013-002.7 Update README and AIDEV docs.
- [x] 0013-002.8 Review, fix, validate, then finish the task.

Architecture impact:

- Adds a small general-purpose request copying helper to `DaylilyCore`.
- Keeps ID generation and timing in `DaylilyObservability`.
- Keeps `DaylilyCore` free from Foundation UUID generation.
- Establishes Daylily's distinction between server-owned request identity and external correlation identity.

Public API impact:

- Adds `Request.with(headers:)`.
- Adds `RequestIDGenerator`.
- Adds request ID header constants.
- Adds `RequestIDMiddleware`.
- Adds `Request.daylilyRequestID`.
- Adds `Request.correlationID`.
- Extends `RequestLog` with optional request/timing/error fields.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0013-observability-middleware.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Completed validation:

```sh
swift build
swift run HelloDaylily --check
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
rg -n "^(import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix)|@_exported import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix))" Sources/DaylilyCore || true
```

Suggested checks:

- Request without `x-request-id` gets generated `x-daylily-request-id`.
- Request without `x-request-id` gets response `x-request-id` equal to generated request ID.
- Request with `x-request-id` preserves that value in response `x-request-id`.
- Request with `x-request-id` still gets a distinct generated `x-daylily-request-id`.
- Error responses still receive request ID headers.
- Handler can read `request.daylilyRequestID`.
- Handler can read `request.correlationID`.
- `RequestLog` records request ID, external correlation ID only when present, duration, and public error reason.
- Duration is greater than or equal to zero.
- `Request.with(headers:)` preserves one-shot body behavior.
- `DaylilyCore` does not import Foundation or NIO.
- `registry.yml` parses.
- `git diff --check` passes.

Notes:

- Vapor uses `X-Request-Id` as `Request.id` when present and generates a UUID when absent.
- Hummingbird core generates its own request ID for logger metadata.
- Daylily intentionally distinguishes `requestID` from `correlationID` so external input cannot define server-side uniqueness.

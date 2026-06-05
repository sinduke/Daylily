# 0021-001 SwiftLog Adapter

Status: implemented
Epic: 0021-ecosystem-compatibility

Goal:

- Add a minimal optional SwiftLog adapter for Daylily request logs.
- Keep Daylily's request logging model independent from SwiftLog.
- Let SwiftLog users plug Daylily request logs into their existing logging setup without Daylily taking over global logging policy.

Scope:

- Add a new `DaylilySwiftLog` product and target.
- Add the official SwiftLog package dependency.
- Implement `SwiftLogRequestLogSink` as a `RequestLogSink`.
- Depend on `DaylilyObservability` and SwiftLog's `Logging` product.
- Keep `DaylilyCore` and `DaylilyObservability` free of `Logging` imports.
- Provide an initializer that accepts a user-owned `Logger`.
- Provide a convenience initializer that accepts a logger label for low-friction adoption.
- Do not call `LoggingSystem.bootstrap(...)`.
- Map `RequestLog` fields into SwiftLog message, level, and metadata.
- Add behavior checks or tests for level mapping, metadata mapping, and module boundary expectations.
- Update docs, AIDEV, registry, capability matrix, and release readiness notes.

Non-goals:

- Backend-specific request logging middleware.
- Replacing `RequestLoggingMiddleware`.
- Replacing `ConsoleRequestLogSink` or `InMemoryRequestLogSink`.
- Adding SwiftLog imports to `DaylilyCore`, `DaylilyObservability`, or the umbrella `Daylily` module.
- Re-exporting `DaylilySwiftLog` from `Daylily`.
- Bootstrapping or configuring global SwiftLog handlers.
- Sampling, batching, async buffering, redaction policy, tracing, or metrics.
- General multi-sink composition such as `MultiplexRequestLogSink`.

Steps:

- [x] 0021-001.1 Add package/product/target wiring for `DaylilySwiftLog`.
- [x] 0021-001.2 Implement `SwiftLogRequestLogSink`.
- [x] 0021-001.3 Add configurable level mapping.
- [x] 0021-001.4 Add metadata mapping.
- [x] 0021-001.5 Add checks or tests.
- [x] 0021-001.6 Update docs and AIDEV.
- [x] 0021-001.7 Validate package, smoke surfaces, YAML, and diff hygiene.
- [x] 0021-001.8 Finish task status.

Architecture impact:

- `DaylilySwiftLog` is an optional adapter module.
- `RequestLoggingMiddleware` remains the only request logging middleware in the default Daylily observability path.
- `RequestLog` remains a Daylily-owned event model.
- `RequestLogSink` remains the output boundary.
- SwiftLog metadata is produced only inside the adapter.
- Applications keep ownership of SwiftLog bootstrap and backend configuration.

Public API proposal:

```swift
public struct SwiftLogRequestLogSink: RequestLogSink {
    public init(
        logger: Logger,
        level: SwiftLogRequestLogLevelStrategy = .statusBased,
        metadata: SwiftLogRequestLogMetadataStrategy = .default
    )

    public init(
        label: String = "daylily.request",
        level: SwiftLogRequestLogLevelStrategy = .statusBased,
        metadata: SwiftLogRequestLogMetadataStrategy = .default
    )
}

public struct SwiftLogRequestLogLevelStrategy: Sendable {
    public static let statusBased: Self
    public static func constant(_ level: Logger.Level) -> Self
}

public struct SwiftLogRequestLogMetadataStrategy: Sendable {
    public static let `default`: Self
}
```

Default usage:

```swift
import Daylily
import DaylilySwiftLog

let app = Application {
    Get("/health") { "ok" }
}
.middleware(
    RequestLoggingMiddleware(
        sink: SwiftLogRequestLogSink()
    )
)
```

User-owned logger usage:

```swift
import Daylily
import DaylilySwiftLog
import Logging

var logger = Logger(label: "commerce-api")
logger[metadataKey: "service"] = "commerce"

let app = Application {
    Get("/health") { "ok" }
}
.middleware(
    RequestLoggingMiddleware(
        sink: SwiftLogRequestLogSink(logger: logger)
    )
)
```

Behavior:

- Default status level mapping:
  - `1xx`, `2xx`, `3xx` -> `.info`
  - `4xx` -> `.warning`
  - `5xx` -> `.error`
- Default message should remain human-readable, for example `GET /products -> 200`.
- Default metadata should include non-empty request log fields such as method, path, status, request ID, correlation ID, duration nanoseconds, and error reason.
- Adapter metadata must be produced at the adapter boundary and must not be stored on `RequestLog`.
- Convenience label initialization may create a `Logger(label:)`, but must not bootstrap `LoggingSystem`.
- Existing user logger metadata should remain under user control.

Validation:

- `swift build`
- `swift test`
- `swift run HelloDaylily --check`
- `scripts/consumer-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/example-smoke-test.sh --mode path`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- Stale status scan for current docs claiming logging backend integration is only planned after implementation is complete.

Completed validation:

- Passed `swift build`.
- Passed `swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `scripts/consumer-smoke-test.sh --mode path`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed `bash -n scripts/consumer-smoke-test.sh scripts/template-smoke-test.sh scripts/example-smoke-test.sh`.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed module boundary scan for `Logging` imports outside `DaylilySwiftLog` and tests.

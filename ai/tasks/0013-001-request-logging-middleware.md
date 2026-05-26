# 0013-001 Request Logging Middleware

Status: implemented
Epic: 0013-observability-middleware

Goal:

- Add the first practical observability slice.
- Provide request logging through normal middleware.
- Keep `DaylilyCore` free from logging backends, tracing SDKs, metrics clients, and transport-specific APIs.

Scope:

- Add a `DaylilyObservability` product and target.
- Re-export `DaylilyObservability` from `Daylily`.
- Add `RequestLog`.
- Add `RequestLogSink`.
- Add `RequestLoggingMiddleware`.
- Add `ConsoleRequestLogSink`.
- Add `InMemoryRequestLogSink`.
- Add behavior checks for success, `ResponseError`, and unknown thrown error cases.
- Update README and AIDEV docs.

Non-goals:

- Request ids.
- Latency timing.
- Metrics backend integration.
- OpenTelemetry dependency.
- Structured logging framework commitment.
- Production dashboard.
- Macro middleware attributes.

Target usage:

```swift
let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

Rules:

- `DaylilyObservability` depends on `DaylilyCore`.
- `DaylilyCore` must not depend on `DaylilyObservability`.
- Request logging must follow the normal middleware contract.
- Successful downstream responses record the returned status.
- Thrown `ResponseError` values record their public status.
- Unknown thrown errors record `500 Internal Server Error`.
- Logging records method, path, and final status in the MVP.

Steps:

- [x] 0013-001.1 Add `DaylilyObservability` package product and target.
- [x] 0013-001.2 Add request log types, sink protocol, and middleware.
- [x] 0013-001.3 Re-export observability from `Daylily`.
- [x] 0013-001.4 Add behavior checks.
- [x] 0013-001.5 Update README and AIDEV docs.
- [x] 0013-001.6 Review, fix, validate, then finish the task.

Architecture impact:

- Adds an observability module parallel to JSON, Testing, and NIO support.
- Keeps the core runtime small and dependency-free.
- Establishes the pattern for later request id, timing, tracing, and metrics slices.

Public API impact:

- Adds `RequestLog`.
- Adds `RequestLogSink`.
- Adds `RequestLoggingMiddleware`.
- Adds `ConsoleRequestLogSink`.
- Adds `InMemoryRequestLogSink`.
- Adds a `DaylilyObservability` product.
- Re-exports `DaylilyObservability` from `Daylily`.

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
```

Suggested checks:

- Successful request records `200 OK`.
- `Abort` or other `ResponseError` records its public status.
- Unknown thrown errors record `500 Internal Server Error`.
- `DaylilyCore` remains independent from `DaylilyObservability`.
- `registry.yml` parses.
- `git diff --check` passes.

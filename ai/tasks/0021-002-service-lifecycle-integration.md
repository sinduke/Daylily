# 0021-002 ServiceLifecycle Integration

Status: implemented
Epic: 0021-ecosystem-compatibility

Goal:

- Add an optional Swift ServiceLifecycle adapter for Daylily applications.
- Let applications run Daylily inside a ServiceLifecycle `ServiceGroup`.
- Keep Daylily lifecycle hooks and signal policy independent from ServiceLifecycle.

Scope:

- Add a new `DaylilyServiceLifecycle` product and target.
- Add the official `swift-service-lifecycle` package dependency.
- Implement `DaylilyApplicationService` as a ServiceLifecycle `Service`.
- Provide a low-friction `Application.serviceLifecycleService(...)` helper.
- Provide `ServerConfiguration.serviceLifecycleDefault` that leaves signal ownership to `ServiceGroup`.
- Add an NIO server shutdown stream SPI so ServiceLifecycle graceful shutdown can close the server without replacing Daylily lifecycle hooks.
- Keep NIO server task cancellation closing the server as a transport-level fallback.
- Add tests and external consumer smoke coverage.
- Update README, docs, capability matrix, release readiness, changelog, and AIDEV registry.

Non-goals:

- Replacing Daylily lifecycle hooks.
- Replacing `Application.run(...)`.
- Re-exporting `DaylilyServiceLifecycle` from the umbrella `Daylily` module.
- Adding ServiceLifecycle imports to `DaylilyCore` or `DaylilyNIO`.
- Creating or configuring a global `ServiceGroup` for applications.
- Moving service ownership into `Dependencies`.
- Implementing the future Daylily-owned `ApplicationService` runtime API.

Checklist:

- [x] 0021-002.1 Add package/product/target wiring for `DaylilyServiceLifecycle`.
- [x] 0021-002.2 Implement `DaylilyApplicationService`.
- [x] 0021-002.3 Add ServiceLifecycle-friendly server configuration defaults.
- [x] 0021-002.4 Add `NIOHTTPServer.run` shutdown stream SPI and task cancellation close fallback.
- [x] 0021-002.5 Add tests for graceful shutdown and configuration defaults.
- [x] 0021-002.6 Extend external consumer smoke coverage.
- [x] 0021-002.7 Update docs, AIDEV registry, roadmap, and release notes.

Public API:

```swift
public struct DaylilyApplicationService: Service {
    public init(
        application: Application,
        configuration: ServerConfiguration = .serviceLifecycleDefault
    )

    public func run() async throws
}

public extension Application {
    func serviceLifecycleService(
        configuration: ServerConfiguration = .serviceLifecycleDefault
    ) -> DaylilyApplicationService
}

public extension ServerConfiguration {
    static var serviceLifecycleDefault: ServerConfiguration

    func withGracefulShutdownSignals(_ enabled: Bool) -> ServerConfiguration
}
```

Example:

```swift
import Daylily
import DaylilyServiceLifecycle
import Logging
import ServiceLifecycle

let app = Application {
    Get("/hello") { "ok" }
}

let serviceGroup = ServiceGroup(
    services: [
        app.serviceLifecycleService()
    ],
    gracefulShutdownSignals: [.sigint, .sigterm],
    logger: Logger(label: "daylily")
)

try await serviceGroup.run()
```

Design decisions:

- `DaylilyServiceLifecycle` depends on `DaylilyCore`, `DaylilyNIO`, and ServiceLifecycle's `ServiceLifecycle` product.
- `DaylilyServiceLifecycle` is optional and is not re-exported by `Daylily`.
- `DaylilyApplicationService` mirrors `Application.run(configuration:)`, so existing Daylily lifecycle phase ordering is preserved.
- `DaylilyApplicationService.run()` maps ServiceLifecycle graceful shutdown to a Daylily NIO server channel close through an adapter-owned shutdown stream.
- `NIOHTTPServer.run` closes its channel when the run task is cancelled.
- `ServerConfiguration.serviceLifecycleDefault` sets `gracefulShutdownSignals` to `false` so `ServiceGroup` can own signal handling by default.
- Applications may pass any `ServerConfiguration`, including one that keeps Daylily's own signal handling enabled.

Validation:

- `swift package resolve`
- `swift build`
- `swift test`
- `scripts/consumer-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/example-smoke-test.sh --mode path`
- `bash -n scripts/consumer-smoke-test.sh scripts/template-smoke-test.sh scripts/example-smoke-test.sh`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`
- `git diff --check`
- Boundary scan for ServiceLifecycle imports outside `DaylilyServiceLifecycle` and tests

Completed validation:

- Passed `swift package resolve`.
- Passed `swift build`.
- Passed `swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `scripts/consumer-smoke-test.sh --mode path`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed shell syntax checks for smoke scripts.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed boundary scan for ServiceLifecycle imports outside `DaylilyServiceLifecycle` and tests.

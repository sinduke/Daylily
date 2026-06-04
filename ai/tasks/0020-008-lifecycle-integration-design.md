# 0020-008 Lifecycle Integration Design

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Design how app-owned services can integrate with Daylily lifecycle.
- Keep resource ownership separate from dependency lookup.
- Preserve `Dependencies` as an access channel, not a lifecycle container.
- Reuse the existing `Application` lifecycle instead of creating a second lifecycle system.

Decision:

- Lifecycle ownership belongs to `Application`, not `Dependencies`.
- `Dependencies` continues to store values for handler and middleware access.
- A future runtime slice may add `ApplicationService` and `Application.service(_:)`.
- The same object may be both registered in `Dependencies` and managed as an `ApplicationService`.
- A managed service does not have to be registered as a dependency.
- No runtime implementation in 0020-008.

Proposed future API:

```swift
public protocol ApplicationService: Sendable {
    func boot() async throws
    func shutdown() async throws
}

public extension Application {
    func service<Service: ApplicationService>(_ service: Service) -> Application
}
```

Example:

```swift
let database = Database.live
let worker = OrderWorker(database: database)

let app = Application(dependencies: { dependencies in
    dependencies.register(database)
}) {
    Get("/products") { request in
        let database = try request.dependencies.require(Database.self)
        return JSON(try await database.products())
    }
}
.service(database)
.service(worker)
```

Boundary:

- `Application` owns service lifecycle.
- `Dependencies` owns lookup only.
- Lifecycle does not imply request access.
- Request access does not imply lifecycle management.
- User-owned composition roots remain valid and may call lifecycle hooks manually.

Lifecycle mapping:

- Managed services boot during the existing `.boot` lifecycle phase.
- Managed services shutdown during the existing `.shutdown` lifecycle phase.
- `.configure`, `.started`, and `.cleanup` remain explicit application hooks.
- No service-specific `configure`, `started`, or `cleanup` methods in the first design.
- `Application.respond(to:)` does not run service lifecycle, matching existing lifecycle behavior.

Ordering:

- Services boot in registration order.
- Services shutdown in reverse registration order.
- Hook registration order and service registration order must be deterministic.
- Existing explicit lifecycle hooks remain available.

Boot failure:

- If a service boot fails, services that already booted should be shut down in reverse order.
- The original boot error must remain visible.
- Shutdown errors during rollback should be collected and surfaced with the original boot error.
- Services that did not finish booting are not shut down by Daylily.

Shutdown failure:

- Shutdown should attempt every started service even if one service fails.
- Shutdown failures should be collected.
- The future runtime should expose a Daylily-owned aggregate error instead of dropping failures.
- Explicit `.shutdown` hooks should continue to behave predictably and should not be silently skipped.

Open design detail for implementation:

- Whether services boot before or after user `.boot` hooks should be decided in the implementation task.
- The preferred direction is user `.boot` hooks first, then services, so application configuration and custom preflight can happen before service startup.
- Shutdown should mirror boot in reverse: services first, then user `.shutdown` hooks.
- This needs focused implementation-time tests because it affects existing lifecycle expectations.

Why not `Dependencies.registerManaged(...)`:

- It would make the dependency registry own resource lifecycle.
- It would blur "can be looked up by handlers" with "must be started and stopped by the app".
- It would make custom composition roots and external containers feel like second-class paths.

Why `ApplicationService`:

- It describes app-owned services, workers, pools, and clients without implying they must be dependencies.
- It keeps lifecycle near the object that already owns lifecycle phases.
- It keeps the future API easy for AI agents to generate and reason about.

Non-goals:

- Runtime implementation in 0020-008.
- Adding `.service(_:)` code now.
- Adding service registration to `Dependencies`.
- Default service discovery.
- Request-scoped services.
- Async factories.
- Keyed dependency runtime implementation.
- `@Dependency` macro.
- Replacing explicit lifecycle hooks.
- Replacing user-owned composition roots.

Follow-up:

- A future implementation task should add runtime service storage, tests, and error types.
- 0020-009 implemented keyed dependency runtime lookup.
- 0020-010 should design `@Dependency` after keyed runtime and service lifecycle contracts are stable.

Validation:

- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- `git diff --check`.
- Trailing whitespace scan for touched docs and AIDEV files.

Completed validation:

- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed trailing whitespace scan for touched docs and AIDEV files.
- Passed consistency search for stale 0020-008 planned/next markers.

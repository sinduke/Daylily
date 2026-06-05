# 0021 Ecosystem Compatibility

Status: implemented

Purpose:

- Make Daylily interoperate cleanly with established Swift server ecosystem packages.
- Add compatibility through optional adapters and boundary types without letting external packages reshape Daylily's core runtime.
- Keep Daylily-owned models useful on their own while making standard ecosystem paths easy to adopt.

Tasks:

- `0021-001-swift-log-adapter` (implemented)
- `0021-002-service-lifecycle-integration` (implemented)
- `0021-003-swift-http-types-adapter` (implemented)
- `0021-004-swift-openapi-generator-transport` (implemented)

Required work:

- SwiftLog adapter as the first small ecosystem bridge.
- ServiceLifecycle integration after logging proves the adapter boundary pattern.
- Swift HTTP Types boundary or adapter layer after lifecycle semantics are clear.
- Swift OpenAPI Generator Daylily transport after standard HTTP boundaries are stable.

Compatibility sequence:

```text
0021-001 SwiftLog Adapter
0021-002 ServiceLifecycle Integration
0021-003 Swift HTTP Types Adapter
0021-004 Swift OpenAPI Generator Transport
```

Delivered:

- `0021-001` adds optional `DaylilySwiftLog` with `SwiftLogRequestLogSink`.
- The adapter keeps SwiftLog out of `DaylilyCore`, `DaylilyObservability`, and the umbrella `Daylily` module.
- Applications own SwiftLog bootstrap and backend policy.
- `0021-002` adds optional `DaylilyServiceLifecycle` with `DaylilyApplicationService`.
- The adapter exposes `Application` as a ServiceLifecycle `Service` without replacing Daylily lifecycle hooks.
- Applications own `ServiceGroup` configuration and signal policy.
- `0021-003` adds optional `DaylilyHTTPTypes` for Swift HTTP Types boundary interop.
- Daylily core now preserves custom method tokens, repeated headers, raw request targets, repeated query parameters, and HTTPTypes pseudo fields needed for lossless adapter boundaries.
- `DaylilyHTTPTypes` throws instead of silently legalizing lossy header/status conversions.
- `0021-004` adds optional `DaylilyOpenAPITransport` for Swift OpenAPI Generator server stubs.
- `DaylilyOpenAPITransport` registers generated handlers as Daylily routes while keeping OpenAPIRuntime out of `DaylilyCore` and the umbrella `Daylily` module.
- OpenAPI whole-segment path parameters map to Daylily route parameters; unsupported mixed segment templates throw during registration.

Design principles:

- Optional ecosystem modules must not add dependencies to `DaylilyCore`.
- Existing Daylily modules must keep working without ecosystem adapters.
- Ecosystem adapters must not replace Daylily-owned runtime models.
- Defaults should make demos easy, but applications must keep control of global configuration and policy.
- Adapter APIs should be thin enough that future `OSLog`, OpenTelemetry, metrics, and transport integrations can follow the same pattern.

Non-goals:

- Replacing `RequestLoggingMiddleware` with backend-specific middleware.
- Bootstrapping global logging or lifecycle systems from Daylily.
- Forcing SwiftLog, ServiceLifecycle, Swift HTTP Types, or Swift OpenAPI Generator onto applications that do not use them.
- Starting ORM, auth, queue, deployment, or broad production platform modules.

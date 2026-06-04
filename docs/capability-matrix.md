# Capability Matrix

This matrix tracks the current beta-facing capability surface. It is intentionally conservative: planned ecosystem work is listed separately from implemented runtime behavior.

## Runtime and HTTP

| Capability | Status | Notes |
| --- | --- | --- |
| Swift package | Implemented | Swift tools version 6.0. |
| Platform declaration | Implemented | macOS 14+ for local package development today. |
| Linux CI | Implemented | GitHub Actions validates with `swift:6.3.2-noble`. |
| External consumer smoke | Implemented | Fresh SwiftPM package validates local path and released package dependency modes. |
| Minimal app template | Implemented | `templates/minimal-app` validates `AppCore`, executable startup, tests, and package dependency modes. |
| Commerce API example | Implemented | `examples/commerce-api` validates a small stateful product/order API in current checkout path mode. |
| Runtime application | Implemented | `Application` owns route dispatch and middleware execution. |
| HTTP transport | Implemented | NIO-backed HTTP/1.1 server. |
| Route DSL | Implemented | `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, `Group`. |
| Path parameters | Implemented | `:name` route syntax and typed extraction. |
| Query/header typed extraction | Implemented | Runtime helpers plus macro input lowering. |
| Request body model | Implemented | `RequestBody` is one-shot and supports buffered or streaming bodies. |
| JSON body decoding | Implemented | `request.body.json(...)` and `request.json(...)`. |
| JSON responses | Implemented | `JSON(...)` response wrapper. |
| Middleware | Implemented | Application, group, and route scope. |
| Lifecycle hooks | Implemented | `configure`, `boot`, `started`, `shutdown`, `cleanup`. |
| Server configuration | Implemented | Host, port, backlog, address reuse, read batching, shutdown signals. |
| Dependencies registry | MVP + keyed runtime | App-wide concrete and keyed `Sendable` registry with `register`, `get`, `require`, `DependencyKey<Value>`, `Request.dependencies`, and documented `makeApplication` usage guidance. |

## Macro Layer

| Capability | Status | Notes |
| --- | --- | --- |
| `@DaylilyServer` | MVP | Generates `static main()` and lowers routes into runtime DSL. |
| HTTP route markers | Implemented | `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`, `@HEAD`, `@OPTIONS`. |
| Route groups | MVP | `@GROUP` on nested structs. |
| `@Path` | Implemented | Typed path input lowering plus metadata. |
| `@Query` | Implemented | Typed query input lowering plus metadata. |
| `@Header` | Implemented | Typed header input lowering plus metadata. |
| `@Body` | Implemented | Preferred typed JSON body input marker. |
| `@JSONBody` | Compatibility | Alias spelling for `@Body`; retained for existing code. |
| `@Dependency` | Implemented | Handler parameter lowering to keyed `Request.dependencies.require(...)`; keyless inference is not supported. |
| Optional typed inputs | Planned | Not implemented yet. |
| Macro middleware attributes | Planned | Runtime middleware exists; macro attributes are future work. |

## Metadata, OpenAPI, and Observability

| Capability | Status | Notes |
| --- | --- | --- |
| Runtime route metadata | Implemented | `Route.describe(...)` and `Application.describeRoutes()`. |
| OpenAPI generation | MVP | Minimal document generation from runtime metadata. |
| Deep Swift schema derivation | Planned | Currently explicit metadata only. |
| Request ID middleware | MVP | Daylily-owned request ID plus external correlation ID behavior. |
| Request logging middleware | MVP | Method, path, status, IDs, duration, and public error reason. |
| Logging backend integration | Planned | Core intentionally avoids backend dependencies. |

## Testing and AI Workflow

| Capability | Status | Notes |
| --- | --- | --- |
| `DaylilyTesting` | Implemented | Transport-free `TestClient`, `TestRequest`, and response assertions. |
| Behavior check suite | Implemented | `swift run HelloDaylily --check`. |
| Formal Swift Testing target | Implemented | `swift test` calls the shared behavior suite. |
| AIDEV project handoff | Implemented | AI-readable architecture, registry, contracts, and playbooks. |
| Machine-readable registry | Implemented | `ai/aidev/registry.yml`. |

## Ecosystem Work

| Capability | Status | Notes |
| --- | --- | --- |
| Protocol/keyed dependencies | Implemented | Typed `DependencyKey<Value>` supports existential values and same-type multi-instance lookup. |
| Lifecycle-managed services | Designed | `ApplicationService` direction is documented; runtime API is not implemented. |
| Authentication | Future | Ecosystem direction, not current runtime. |
| ORM/database module | Future | Explicitly out of current beta closure. |
| Queue/background jobs | Future | Ecosystem direction. |
| WebSocket/realtime | Future | Ecosystem direction. |
| Deployment tooling | Future | Release/deploy story comes after alpha release hygiene. |
| Benchmarks | Planned | To publish after runtime and beta docs stabilize. |

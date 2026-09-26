# Capability Matrix

This matrix tracks the current beta-facing capability surface. The operational work is part of alpha.3; use versioned docs for release capabilities. It is intentionally conservative: planned ecosystem work is listed separately from implemented runtime behavior.

## Runtime and HTTP

| Capability | Status | Notes |
| --- | --- | --- |
| Swift package | Implemented | Swift tools version 6.3; Swift 6.3.2 is the validated compiler. |
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
| Lossless HTTP boundary | Implemented | Custom method tokens, repeated headers, raw request targets, repeated query parameters, and HTTPTypes pseudo fields are preserved at adapter boundaries. |
| JSON body decoding | Implemented | `request.body.json(...)` and `request.json(...)`. |
| JSON responses | Implemented | `JSON(...)` response wrapper. |
| Streaming responses and SSE | Implemented | `ResponseBody.stream`, awaited writes, cancellation, explicit collection, and `Response.eventStream`. |
| Lifecycle failure recovery | Implemented | Shared runner, teardown once, all teardown hooks attempted, aggregated failures. |
| Middleware | Implemented | Application, group, and route scope. |
| Lifecycle hooks | Implemented | `configure`, `boot`, `started`, `shutdown`, `cleanup`. |
| Server configuration | Implemented | Host, port, backlog, address reuse, read batching, signals, header/upload idle deadlines and bounded graceful drain. |
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
| `@Use` | Implemented | App, group, and route middleware lowering; accepts a single Swift expression, including named values. |
| `@Security` | Implemented | Route-level explicit security metadata lowering for OpenAPI operation security. |
| Optional query/header inputs | Implemented | `T?`, `Optional<T>`, and `Swift.Optional<T>` lower to runtime `get`; optional path inputs are rejected. |

## Metadata, OpenAPI, and Observability

| Capability | Status | Notes |
| --- | --- | --- |
| Runtime route metadata | Implemented | `Route.describe(...)` and `Application.describeRoutes()`. |
| OpenAPI generation | MVP | Minimal document generation from runtime metadata. |
| OpenAPI operation security | Implemented | Explicit route security metadata maps to operation `security`; explicit security scheme components are registered and validated. |
| Explicit OpenAPI schemas | Implemented | Object, array, string enum, local references, named components, and validation. |
| Generated server/client round trip | Implemented | `examples/openapi-service` runs actual generated code over HTTP with ServiceGroup and SwiftLog. |
| Response-transfer observation | Implemented (alpha.3) | Terminal outcome, flushed body bytes and transfer duration, separate from handler logs; optional console/in-memory/SwiftLog observers. |
| Contract evolution regression | Implemented | Conservative OpenAPI subset diff plus actual old/new generated clients over HTTP. |
| Deep Swift schema derivation | Planned | Explicit schema registration remains the supported path. |
| Request ID middleware | MVP | Daylily-owned request ID plus external correlation ID behavior. |
| Request logging middleware | MVP | Method, path, status, IDs, duration, and public error reason. |
| Logging backend integration | Implemented | Optional `DaylilySwiftLog` adapter; core intentionally avoids backend dependencies. |

## Testing and AI Workflow

| Capability | Status | Notes |
| --- | --- | --- |
| `DaylilyTesting` | Implemented | Transport-free `TestClient`, `TestRequest`, and response assertions. |
| Behavior check suite | Implemented | `swift run HelloDaylily --check`. |
| Formal Swift Testing target | Implemented | `swift test` calls the shared behavior suite. |
| AIDEV project handoff | Implemented | AI-readable architecture, registry, contracts, and playbooks. |
| Repeated actual AI changes | Implemented | Three fixed edits × two isolated runs with immutable acceptance and recorded patches/timing/usage; opt-in. |
| Machine-readable registry | Implemented | `ai/aidev/registry.yml`. |

## Ecosystem Work

| Capability | Status | Notes |
| --- | --- | --- |
| Protocol/keyed dependencies | Implemented | Typed `DependencyKey<Value>` supports existential values and same-type multi-instance lookup. |
| SwiftLog adapter | Implemented | Optional `DaylilySwiftLog` `RequestLogSink`, not a replacement middleware. |
| ServiceLifecycle integration | Implemented | Optional `DaylilyServiceLifecycle` adapter that exposes `Application` as a ServiceLifecycle `Service`. |
| Swift HTTP Types adapter | Implemented | Optional `DaylilyHTTPTypes` adapter converting Daylily requests/responses to Swift HTTP Types without silently lossy legalization. |
| Swift OpenAPI Generator transport | Implemented | Optional `DaylilyOpenAPITransport` server transport for generated handlers; whole-segment path parameters only. |
| Lifecycle-managed services | Designed | `ApplicationService` direction is documented; runtime API is not implemented. |
| Authentication | Future | Ecosystem direction, not current runtime. |
| ORM/database module | Future | Explicitly out of current beta closure. |
| Queue/background jobs | Future | Ecosystem direction. |
| WebSocket/realtime | Future | Ecosystem direction. |
| Container deployment trial | Implemented | Two Linux replicas behind Caddy, rolling shutdown, SSE/disconnect/slow-peer checks and bounded sustained traffic. Public cloud automation remains future work. |
| Benchmarks | Planned | To publish after runtime and beta docs stabilize. |

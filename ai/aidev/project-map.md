# Project Map

## Root

```text
Daylily/
├── AIDEV.md
├── DAYLILY_NOTES.md
├── Package.swift
├── CHANGELOG.md
├── README.md
├── README.zh-CN.md
├── scripts/
│   ├── consumer-smoke-test.sh
│   ├── example-smoke-test.sh
│   └── template-smoke-test.sh
├── templates/
│   └── minimal-app/
├── examples/
│   └── commerce-api/
├── docs/
│   ├── README.md
│   ├── quickstart.md
│   ├── capability-matrix.md
│   ├── release-readiness.md
│   └── examples/
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
│   ├── DaylilyMacros/
│   ├── DaylilyNIO/
│   ├── DaylilyObservability/
│   ├── DaylilyOpenAPI/
│   ├── DaylilyTesting/
│   ├── DaylilyCheckSuite/
│   └── HelloDaylily/
├── Tests/
│   └── DaylilyTests/
└── ai/
    ├── epics/
    ├── aidev/
    ├── prompts/
    └── tasks/
```

## User-Facing Docs

`docs/README.md`

- Beta documentation hub.
- Links quickstart, capability matrix, examples, and deeper AIDEV documents.

`docs/quickstart.md`

- SwiftPM package and repository checkout quickstart for the current experimental phase.
- Covers package installation, build, checks, tests, running the example server, first requests, and external consumer smoke validation.

`docs/capability-matrix.md`

- Conservative status matrix for implemented, MVP, planned, and future capabilities.

`docs/release-readiness.md`

- Current release status, CI coverage, tag strategy, and known release limitations.

`docs/examples/`

- Focused beta examples for dependencies usage, the commerce API, JSON APIs, middleware, and transport-free testing.
- `docs/examples/dependencies.md` owns the `makeApplication`, test override, custom service wiring, typed dependency key, and managed service lifecycle design guidance.

`CHANGELOG.md`

- Human-facing release notes.
- Tracks unreleased changes and candidate tag guidance.

## Scripts

`scripts/consumer-smoke-test.sh`

- Generates a fresh external SwiftPM package outside the repository.
- Validates `Daylily` as a local path dependency or released package dependency.
- Builds runtime and macro executable targets.
- In path mode, starts the generated macro app and verifies a macro `@Dependency` route over HTTP.
- In release mode, keeps the generated macro source compatible with the selected published tag.
- Runs a Swift Testing target that imports `DaylilyTesting`.

`scripts/template-smoke-test.sh`

- Copies `templates/minimal-app` to a temporary external directory.
- Removes copied `.build` and `Package.resolved` artifacts so local builds cannot pollute smoke packages.
- Rewrites the Daylily dependency for path, release, or branch validation.
- Runs `swift package resolve`, `swift build`, `swift test`, and `swift run App --check`.

`scripts/example-smoke-test.sh`

- Validates `examples/commerce-api` through the same external package smoke path.
- Supports path, release, and branch dependency modes through `scripts/template-smoke-test.sh`.

## Templates

`templates/minimal-app`

- Recommended minimal external Daylily app structure.
- Uses `AppCore` for application construction and route declarations.
- Uses `App` for process startup.
- Uses `AppCoreTests` with `DaylilyTesting` for in-memory tests.
- Source intentionally stays free of `Dependencies` until the current dependency API is included in a release tag.

## Examples

`examples/commerce-api`

- First real API example for package consumers.
- Uses `AppCore` for a product/order API with an actor-backed in-memory store.
- Uses `makeApplication(store:)` for common overrides and `makeApplication(configureDependencies:)` for registry-level overrides.
- Uses `App` for process startup and `--check`.
- Uses `AppCoreTests` with `DaylilyTesting` for in-memory tests.

## Package Products and Targets

`Daylily`

- Public user-facing library.
- Re-exports `DaylilyCore`, `DaylilyJSON`, `DaylilyNIO`, `DaylilyObservability`, and `DaylilyOpenAPI`.
- Adds `Application.run(host:port:responseObserver:)` and `run(configuration:responseObserver:)`, both with an optional nil observer.
- Exposes `@DaylilyServer`, HTTP route marker macros, and `@GROUP`.

`DaylilyCore`

- Framework runtime.
- Owns request, response, body, dependencies, route, route metadata, routes, router, middleware, handler, status, headers, parameters, errors.
- Owns transport-free server deadline configuration and response-transfer events/observer protocol.
- Must stay independent from NIO and transport-specific APIs.

`DaylilyJSON`

- JSON convenience module.
- Depends on `DaylilyCore` and Foundation.
- Owns `request.json(...)` body decoding and `JSON(...)` response conversion.
- Keeps JSON/Foundation concerns out of `DaylilyCore`.

`DaylilyMacros`

- Internal macro target.
- Swift macro implementation target.
- Owns the compiler plugin for `@DaylilyServer`, HTTP route markers, and `@GROUP`.
- Must lower macro syntax into runtime APIs instead of bypassing them.
- Lowers typed macro inputs into runtime route metadata.

`DaylilyNIO`

- NIO-backed HTTP transport.
- Creates Daylily `Request` after NIO request head with a streaming `RequestBody`.
- Feeds NIO body chunks into `BodyBytes` without exposing NIO types.
- Uses bounded buffering and practical backpressure for request bodies.
- Converts Daylily `Response` into NIO HTTP response parts.
- Owns header/upload deadlines, graceful connection drain, forced closure, and terminal transfer accounting.

`DaylilyObservability`

- Optional observability helpers.
- Depends on `DaylilyCore`.
- Owns `RequestIDMiddleware`, `RequestLoggingMiddleware`, `RequestLog`, and request log sinks.
- Provides optional in-memory and console response-transfer observers.
- Must not pull logging backends, tracing SDKs, or transport-specific APIs into `DaylilyCore`.

`DaylilySwiftLog`

- Optional SwiftLog adapter.
- Directly depends on `DaylilyCore`, `DaylilyObservability`, and SwiftLog's `Logging` product.
- Owns `SwiftLogRequestLogSink`, `SwiftLogRequestLogLevelStrategy`, and `SwiftLogRequestLogMetadataStrategy`.
- Owns `SwiftLogResponseTransferObserver` for terminal outcomes, flushed body bytes, and transfer duration.
- Is not re-exported by the umbrella `Daylily` module.
- Must not call `LoggingSystem.bootstrap(...)`.

`DaylilyServiceLifecycle`

- Optional Swift ServiceLifecycle adapter.
- Depends on `DaylilyCore`, `DaylilyNIO`, and ServiceLifecycle's `ServiceLifecycle` product.
- Owns `DaylilyApplicationService` and ServiceLifecycle-specific `ServerConfiguration` helpers.
- Is not re-exported by the umbrella `Daylily` module.
- Must not create or configure a global `ServiceGroup`.

`DaylilyHTTPTypes`

- Optional Swift HTTP Types adapter.
- Depends on `DaylilyCore` and Swift HTTP Types' `HTTPTypes` product.
- Owns request, response, and headers conversions between Daylily and Swift HTTP Types.
- Is not re-exported by the umbrella `Daylily` module.
- Must not replace Daylily-owned request/response models or consume `RequestBody`.

`DaylilyOpenAPITransport`

- Optional Swift OpenAPI Generator server transport adapter.
- Depends on `DaylilyCore`, `DaylilyHTTPTypes`, OpenAPIRuntime, and Swift HTTP Types' `HTTPTypes` product.
- Owns `DaylilyOpenAPITransport`, which conforms to OpenAPIRuntime `ServerTransport`.
- Is not re-exported by the umbrella `Daylily` module.
- Must not replace Daylily-owned routing, application startup, request, or response models.

`DaylilyOpenAPI`

- Minimal OpenAPI document generation.
- Depends on `DaylilyCore`.
- Owns OpenAPI DTOs and `Application.openAPI(title:version:)`.
- Reads `Application.describeRoutes()` and maps runtime metadata into an OpenAPI document.
- Does not derive deep Swift schemas in the MVP.

`DaylilyTesting`

- Transport-free testing helpers.
- Depends on `DaylilyCore`.
- Owns `TestClient`, which calls `Application.respond(to:)` directly.
- Owns `TestRequest` for in-memory request construction.
- Owns response assertion helpers such as `requireStatus(_:)`, `requireBody(_:)`, and `requireJSON(_:as:)`.
- Must not depend on NIO.

`DaylilyCheckSuite`

- Internal shared behavior check target.
- Depends on `Daylily`, `DaylilyCore`, and `DaylilyTesting`.
- Owns `DaylilyChecks.run()` and shared example DTOs.
- Used by both `swift run HelloDaylily --check` and `swift test`.

`HelloDaylily`

- Example executable and smoke-check entrypoint.
- Default `swift run` launches the HTTP server.
- `swift run HelloDaylily --check` runs `DaylilyCheckSuite`.
- Includes `/upload/count` for chunked upload smoke checks.

`DaylilyTests`

- Formal Swift Testing target under `Tests/DaylilyTests`.
- Runs the shared `DaylilyCheckSuite` through `swift test`.
- Adds focused test-target coverage for `DaylilyTesting` without opening a port.

## Source Files

`Sources/Daylily/Application+Run.swift`

- Extends `Application` with `run(host:port:)`.
- Bridges user-facing app runtime to `NIOHTTPServer`.

`Sources/Daylily/Exports.swift`

- Re-exports `DaylilyCore`, `DaylilyJSON`, `DaylilyNIO`, `DaylilyObservability`, and `DaylilyOpenAPI`.

`Sources/Daylily/Macros.swift`

- Public macro declarations for `@DaylilyServer`, HTTP route markers, and `@GROUP`.

`Sources/DaylilyCore/Application.swift`

- Holds `Router`.
- Entrypoint for in-memory request handling via `respond(to:)`.
- Stores application middleware.
- Owns the app-wide `Dependencies` value and stamps it onto requests.
- Converts `ResponseError` failures into responses.

`Sources/DaylilyCore/Body.swift`

- Defines `RequestBody`, `BodyBytes`, `ByteChunk`, `ByteCount`, and `BodyError`.
- Implements the 0008-001 one-shot body model.
- Buffered bodies yield one `ByteChunk`; streaming bodies yield transport-fed chunks.

`Sources/DaylilyCore/Errors.swift`

- Defines `ResponseError` and `Abort`.

`Sources/DaylilyCore/Dependencies.swift`

- Defines the app-wide `Dependencies` registry MVP.
- Defines `DependencyKey<Value>` and the `Dependency<Value>` macro marker.
- Defines `DependencyError` for missing required dependencies.
- Stores concrete `Sendable` values by concrete metatype and keyed values by typed dependency key.

`Sources/DaylilyCore/Handler.swift`

- Wraps route closures into one async response function.

`Sources/DaylilyCore/Headers.swift`

- Case-normalized header storage.

`Sources/DaylilyCore/HTTPMethod.swift`

- HTTP method enum for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.

`Sources/DaylilyCore/Middleware.swift`

- Defines the public `Middleware` protocol.
- Defines internal middleware type erasure and pipeline composition.

`Sources/DaylilyCore/Lifecycle.swift`

- Defines `LifecycleOperation` and `LifecyclePhase`.
- Lifecycle hook storage and execution is owned by `Application`.

`Sources/DaylilyCore/Parameters.swift`

- Path parameter container with dynamic member access.
- Typed path extraction through `ParameterDecodable`.
- `ParameterError` response mapping for missing and invalid typed parameters.

`Sources/DaylilyCore/QueryParameters.swift`

- Query parameter container with dynamic member access.
- Typed query extraction through `ParameterDecodable`.
- `QueryParameterError` response mapping for missing and invalid typed query parameters.

`Sources/DaylilyCore/Path.swift`

- Public `@Path` parameter marker used by `@DaylilyServer`.
- Keeps macro syntax valid while extraction remains in `Parameters.require(_:as:)`.

`Sources/DaylilyCore/Query.swift`

- Public `@Query` parameter marker used by `@DaylilyServer`.

`Sources/DaylilyCore/Header.swift`

- Public `@Header` parameter marker used by `@DaylilyServer`.

`Sources/DaylilyCore/Request.swift`

- Method, path, headers, `RequestBody`, path parameters, query parameters, and dependencies.
- Request copy helpers for parameters, body replacement, dependency replacement, and explicit buffered body replacement.

`Sources/DaylilyCore/ServerConfiguration.swift`

- NIO-free server configuration consumed by `Application.run(configuration:responseObserver:)`.
- Defines optional header/upload/grace durations (15/30/10 seconds by default); nil disables the corresponding deadline.

`Sources/DaylilyCore/ResponseTransfer.swift`

- Defines immutable `ResponseTransferEvent`, `ResponseTransferOutcome`, and nonthrowing async `ResponseTransferObserver`.
- Keeps transfer observation independent of NIO and logging backends.

`Sources/DaylilyCore/Response.swift`

- Response model and `ResponseConvertible`.

`Sources/DaylilyCore/Route.swift`

- Route and `Routes` models.
- `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, and `Group` runtime DSL.
- Stores route middleware and group middleware resolution.
- Stores route metadata.

`Sources/DaylilyCore/RouteMetadata.swift`

- Defines `RouteMetadata`.
- Defines route input/body/response metadata.
- Defines `RouteDescription` for `Application.describeRoutes()`.

`Sources/DaylilyCore/RouteBuilder.swift`

- Result builder for route lists and `Routes` group collections.

`Sources/DaylilyCore/Router.swift`

- Matches request method/path to a route.

`Sources/DaylilyCore/Status.swift`

- HTTP status model, including `413 Payload Too Large`.

`Sources/DaylilyJSON/JSON.swift`

- Defines the `JSON<Value>` response wrapper.
- Adds async `RequestBody.json(_:upTo:)` and `Request.json(_:upTo:)` body decoding.
- Converts JSON decode failures into `Abort(.badRequest, reason: "Invalid JSON body")`.

`Sources/DaylilyJSON/JSONBody.swift`

- Public `@Body` marker used by `@DaylilyServer`; `@JSONBody` remains as a compatibility alias spelling.
- Keeps JSON body marker ownership with the JSON module.

`Sources/DaylilyMacros/DaylilyMacros.swift`

- Macro implementation and compiler plugin registration.
- `@DaylilyServer` scans route methods and group structs, then generates `static main() async throws`.
- HTTP route markers and `@GROUP` are marker macros used by `@DaylilyServer`.
- `@Path`, `@Query`, `@Header`, and preferred `@Body` handler inputs lower into runtime extraction and route metadata; `@JSONBody` is the compatibility alias spelling for `@Body`.

`Sources/DaylilyNIO/NIOHTTPServer.swift`

- NIO HTTP server and channel handler.
- Accepts a `started` callback so `Application.run` can run lifecycle after bind.
- Exposes a ServiceLifecycle SPI shutdown stream used by `DaylilyServiceLifecycle`.
- Quiesces the listener/connections and drains active responses within the configured grace period; task cancellation force-closes immediately.
- Owns inbound deadline timers and their suspension during transport backpressure.
- Arbitrates exactly one terminal transfer event on the event loop and delivers it from a Swift task. Channel task gates reject late work after closure.

`Sources/DaylilyObservability/RequestLoggingMiddleware.swift`

- Defines `RequestLog`.
- Defines `RequestLogSink`.
- Defines `RequestLoggingMiddleware`.
- Provides `ConsoleRequestLogSink` and `InMemoryRequestLogSink`.

`Sources/DaylilyObservability/ResponseTransferObservers.swift`

- Provides `InMemoryResponseTransferObserver` for local inspection/tests and `ConsoleResponseTransferObserver` for terminal transfer output.
- In-memory retention is unbounded; applications own production retention/export.

`Sources/DaylilySwiftLog/SwiftLogRequestLogSink.swift`

- Defines the optional SwiftLog request log sink adapter.
- Maps `RequestLog` values into SwiftLog message, level, and metadata.
- Keeps SwiftLog metadata at the adapter boundary.

`Sources/DaylilySwiftLog/SwiftLogResponseTransferObserver.swift`

- Maps terminal outcomes to SwiftLog levels and metadata without bootstrapping a backend.
- Uses `daylily.response.transfer_duration_ns` separately from handler request duration.

`Sources/DaylilyServiceLifecycle/DaylilyApplicationService.swift`

- Defines the optional Swift ServiceLifecycle application adapter.
- Adapts `Application` into a ServiceLifecycle `Service`.
- Provides `Application.serviceLifecycleService(...)`.
- Forwards the optional response observer through its initializer and application helper.
- Provides `ServerConfiguration.serviceLifecycleDefault` and `withGracefulShutdownSignals(_:)`.

`Sources/DaylilyHTTPTypes/HTTPTypesAdapter.swift`

- Defines the optional Swift HTTP Types adapter.
- Converts between Daylily `Request`/`Response` and Swift HTTP Types `HTTPRequest`/`HTTPResponse`.
- Converts ordered Daylily `Headers` and Swift HTTP Types `HTTPFields`.
- Throws on conversions that would require silently lossy header/status legalization.

`Sources/DaylilyOpenAPITransport/DaylilyOpenAPITransport.swift`

- Defines the optional Swift OpenAPI Generator server transport adapter.
- Converts generated OpenAPIRuntime handler registrations into Daylily routes.
- Bridges Daylily one-shot request bodies to OpenAPIRuntime `HTTPBody`.
- Streams OpenAPIRuntime response bodies by default; explicit collection retains a bounded buffer.
- Rejects unsupported path templates during registration.

`Sources/DaylilyObservability/RequestIDMiddleware.swift`

- Defines `RequestIDMiddleware`.
- Defines `RequestIDGenerator`, `RequestIDs`, and `RequestIDHeaders`.
- Adds `Request.daylilyRequestID`, `Request.correlationID`, and `Request.withRequestIDs(...)`.

`Sources/DaylilyOpenAPI/OpenAPI.swift`

- Defines minimal OpenAPI DTOs.
- Defines `OpenAPIBuilder`.
- Adds `Application.openAPI(title:version:openapi:)`.

`Sources/DaylilyTesting/TestClient.swift`

- In-memory test client.
- Provides `respond(to:)`, `send(_:)`, verb helpers, and `postJSON(_:headers:body:)`.
- Reuses `Application`, `Request`, `Response`, `Headers`, and `RequestBody`.

`Sources/DaylilyTesting/TestRequest.swift`

- Test request builder for method, path, headers, body, and JSON body construction.

`Sources/DaylilyTesting/ResponseAssertions.swift`

- Response JSON decoding and throwing assertion helpers for tests.

`Sources/HelloDaylily/HelloDaylily.swift`

- Default executable entry.

`Sources/DaylilyCheckSuite/Checks.swift`

- Shared behavior checks, including `DaylilyTesting` coverage, used by the executable check command and formal test target.

`Sources/DaylilyCheckSuite/Payloads.swift`

- Shared DTOs for example JSON routes and checks.

`Sources/HelloDaylily/MacroSmoke.swift`

- Compile-time smoke coverage for macro route/group MVP, including `@Path`, `@Query`, `@Header`, `@Dependency`, preferred `@Body`, and `@JSONBody` compatibility handler inputs.

`Tests/DaylilyTests/DaylilyBehaviorTests.swift`

- Swift Testing entrypoint for the shared behavior suite.
- Verifies the formal test target can exercise `DaylilyTesting` without opening a port.

## AI Files

`ai/tasks/`

- Task notes and implementation records.
- File names use `NNNN-XXX-short-kebab-name.md`.
- Tasks are the smallest commit/push unit.
- Steps are tracked inside task files, not as separate task files.

`ai/epics/`

- Theme-level planning containers.
- File names use `NNNN-short-kebab-name.md`.
- Epics are not direct implementation units.

`ai/aidev/`

- AI operating system for the project.

`ai/prompts/`

- Standard prompts for AI agents that take over Daylily work.

## AIDEV Files

`ai/aidev/start-here.md`

- First file for AI handoff.

`ai/aidev/concepts.md`

- Core concepts and mental model.

`ai/aidev/runtime-contracts.md`

- Runtime contracts by component.

`ai/aidev/invariants.md`

- Rules that must not be broken.

`ai/aidev/extension-playbooks.md`

- Step-by-step recipes for adding features.

`ai/aidev/task-protocol.md`

- Required task format and lifecycle.

`ai/prompts/daylily-agent.md`

- Standard agent prompt for future AI sessions.


## Reliability Delivery (0023)

- `Sources/DaylilyCore/ResponseBody.swift`: demand-driven body, writer state, SSE encoding, errors.
- `Sources/DaylilyCore/Application.swift` / `Lifecycle.swift`: shared lifecycle execution and aggregate failures.
- `Sources/DaylilyOpenAPI/OpenAPISchema.swift` / `OpenAPIValidation.swift`: explicit components and supported-subset validation.
- `Tests/DaylilyTests/ResponseStreamingTests.swift`: real socket and cancellation regressions.
- `Tests/DaylilyTests/LifecycleRecoveryTests.swift`: failure/teardown and adapter parity.
- `Tests/DaylilyTests/OptionalInputTests.swift`: optional runtime semantics and schema metadata; macro HTTP/negative compile checks live in the consumer script.
- `examples/openapi-service`: spec exporter, actual generator plugin, generated client/server HTTP example.
- `ai/evals/application-changes`: three fixed application exercises, reference implementations, and acceptance tests.
- `scripts/smoke-common.sh`: dependency profiles, exact pin verification, isolated workspaces and process cleanup.
- `scripts/openapi-smoke-test.sh` / `scripts/ai-exercises-smoke-test.sh`: external generation and application exercise validation.
- `docs/reliability-and-streaming.md`: current-checkout behavior and migration guide.

## Operational Readiness (0024, in progress)

- `ai/epics/0024-release-and-operational-readiness.md` and tasks `0024-001` through `0024-006` track release, deadlines/drain, transfer observation, deployment, contract/AI regression, and final closure. Implementation does not imply that every acceptance gate has completed.
- `Tests/DaylilyTests/ServerOperationTests.swift`: real-socket deadline, backpressure, drain, terminal-event, and observer-isolation regressions.
- `Tests/DaylilyTests/ResponseTransferObserverTests.swift`: collector concurrency and SwiftLog adapter metadata/levels.
- `examples/deployment-trial`: independent API/SSE consumer, Linux image, two-replica reverse-proxy trial application.
- `scripts/deployment-trial.py`: loopback host ports, bounded operational checks, scoped Docker cleanup, and preserved evidence.
- `scripts/openapi-compatibility-check.py` and `ai/evals/contracts`: supported-subset compatibility checks and fixtures.
- `ai/evals/repeated-changes`: fixed application-edit fixtures, isolated agent runner, open-test acceptance checks, and retained run evidence; this is not a blinded test or general benchmark.

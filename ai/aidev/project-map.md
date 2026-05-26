# Project Map

## Root

```text
Daylily/
├── AIDEV.md
├── DAYLILY_NOTES.md
├── Package.swift
├── README.md
├── README.zh-CN.md
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
│   ├── DaylilyMacros/
│   ├── DaylilyNIO/
│   ├── DaylilyObservability/
│   ├── DaylilyOpenAPI/
│   ├── DaylilyTesting/
│   └── HelloDaylily/
└── ai/
    ├── epics/
    ├── aidev/
    ├── prompts/
    └── tasks/
```

## Package Products and Targets

`Daylily`

- Public user-facing library.
- Re-exports `DaylilyCore`, `DaylilyJSON`, `DaylilyNIO`, `DaylilyObservability`, and `DaylilyOpenAPI`.
- Adds `Application.run(host:port:)`.
- Exposes `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.

`DaylilyCore`

- Framework runtime.
- Owns request, response, body, route, route metadata, routes, router, middleware, handler, status, headers, parameters, errors.
- Must stay independent from NIO and transport-specific APIs.

`DaylilyJSON`

- JSON convenience module.
- Depends on `DaylilyCore` and Foundation.
- Owns `request.json(...)` body decoding and `JSON(...)` response conversion.
- Keeps JSON/Foundation concerns out of `DaylilyCore`.

`DaylilyMacros`

- Internal macro target.
- Swift macro implementation target.
- Owns the compiler plugin for `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.
- Must lower macro syntax into runtime APIs instead of bypassing them.
- Lowers typed macro inputs into runtime route metadata.

`DaylilyNIO`

- NIO-backed HTTP transport.
- Creates Daylily `Request` after NIO request head with a streaming `Body`.
- Feeds NIO body chunks into `BodyBytes` without exposing NIO types.
- Uses bounded buffering and practical backpressure for request bodies.
- Converts Daylily `Response` into NIO HTTP response parts.

`DaylilyObservability`

- Optional observability helpers.
- Depends on `DaylilyCore`.
- Owns `RequestIDMiddleware`, `RequestLoggingMiddleware`, `RequestLog`, and request log sinks.
- Must not pull logging backends, tracing SDKs, or transport-specific APIs into `DaylilyCore`.

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

`HelloDaylily`

- Example executable and current smoke-check host.
- Default `swift run` launches the HTTP server.
- `swift run HelloDaylily --check` runs in-process runtime checks.
- Includes `/upload/count` for chunked upload smoke checks.

## Source Files

`Sources/Daylily/Application+Run.swift`

- Extends `Application` with `run(host:port:)`.
- Bridges user-facing app runtime to `NIOHTTPServer`.

`Sources/Daylily/Exports.swift`

- Re-exports `DaylilyCore`, `DaylilyJSON`, `DaylilyNIO`, `DaylilyObservability`, and `DaylilyOpenAPI`.

`Sources/Daylily/Macros.swift`

- Public macro declarations for `@DaylilyServer`, `@GET`, `@POST`, and `@GROUP`.

`Sources/DaylilyCore/Application.swift`

- Holds `Router`.
- Entrypoint for in-memory request handling via `respond(to:)`.
- Stores application middleware.
- Converts `ResponseError` failures into responses.

`Sources/DaylilyCore/Body.swift`

- Defines `Body`, `BodyBytes`, `ByteChunk`, `ByteCount`, and `BodyError`.
- Implements the 0008-001 one-shot body model.
- Buffered bodies yield one `ByteChunk`; streaming bodies yield transport-fed chunks.

`Sources/DaylilyCore/Errors.swift`

- Defines `ResponseError` and `Abort`.

`Sources/DaylilyCore/Handler.swift`

- Wraps route closures into one async response function.

`Sources/DaylilyCore/Headers.swift`

- Case-normalized header storage.

`Sources/DaylilyCore/HTTPMethod.swift`

- HTTP method enum.

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

- Method, path, headers, `Body`, path parameters, and query parameters.
- Request copy helpers for parameters, body replacement, and explicit buffered body replacement.

`Sources/DaylilyCore/ServerConfiguration.swift`

- NIO-free server configuration consumed by `Application.run(configuration:)`.

`Sources/DaylilyCore/Response.swift`

- Response model and `ResponseConvertible`.

`Sources/DaylilyCore/Route.swift`

- Route and `Routes` models.
- `Get`, `Post`, `Group` runtime DSL.
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
- Adds async `Body.json(_:upTo:)` and `Request.json(_:upTo:)` body decoding.
- Converts JSON decode failures into `Abort(.badRequest, reason: "Invalid JSON body")`.

`Sources/DaylilyJSON/JSONBody.swift`

- Public `@JSONBody` marker used by `@DaylilyServer`.
- Keeps JSON body marker ownership with the JSON module.

`Sources/DaylilyMacros/DaylilyMacros.swift`

- Macro implementation and compiler plugin registration.
- `@DaylilyServer` scans route methods and group structs, then generates `static main() async throws`.
- `@GET`, `@POST`, and `@GROUP` are marker macros used by `@DaylilyServer`.
- `@Path`, `@Query`, `@Header`, and `@JSONBody` handler inputs lower into runtime extraction and route metadata.

`Sources/DaylilyNIO/NIOHTTPServer.swift`

- NIO HTTP server and channel handler.
- Accepts a `started` callback so `Application.run` can run lifecycle after bind.

`Sources/DaylilyObservability/RequestLoggingMiddleware.swift`

- Defines `RequestLog`.
- Defines `RequestLogSink`.
- Defines `RequestLoggingMiddleware`.
- Provides `ConsoleRequestLogSink` and `InMemoryRequestLogSink`.

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
- Provides `respond(to:)`, `send(_:)`, `get(_:)`, `post(_:body:)`, and `postJSON(_:headers:body:)`.
- Reuses `Application`, `Request`, `Response`, `Headers`, and `Body`.

`Sources/DaylilyTesting/TestRequest.swift`

- Test request builder for method, path, headers, body, and JSON body construction.

`Sources/DaylilyTesting/ResponseAssertions.swift`

- Response JSON decoding and throwing assertion helpers for tests.

`Sources/HelloDaylily/HelloDaylily.swift`

- Default executable entry.

`Sources/HelloDaylily/Checks.swift`

- Lightweight checks, including `DaylilyTesting` coverage, used until a dedicated test target is added.

`Sources/HelloDaylily/Payloads.swift`

- Shared DTOs for example JSON routes and checks.

`Sources/HelloDaylily/MacroSmoke.swift`

- Compile-time smoke coverage for macro route/group MVP, including `@Path` and `@JSONBody` handler inputs.

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

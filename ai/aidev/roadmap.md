# Roadmap

Daylily now uses an Epic / Task / Step planning model.

```text
Epic -> Task -> Step
```

- Epics live in `ai/epics/`.
- Tasks live in `ai/tasks/`.
- Steps live inside task files as checklists.
- Tasks are the smallest commit/push unit.

## Epics

### 0001 Runtime Foundation

Status: implemented

Tasks:

- `0001-001-minimal-http-server`

Delivered:

- Swift package skeleton.
- Runtime route DSL.
- `Application.respond(to:)`.
- NIO HTTP transport.
- Default `swift run` server.
- `swift run HelloDaylily --check` behavior checks.
- Formal `swift test` entrypoint.
- Basic `Get`, `Post`, and `Group`.
- Path parameter matching.
- 404 behavior.

### 0002 AIDEV System

Status: implemented

Tasks:

- `0002-001-aidev-project-contract`
- `0002-002-aidev-self-contained-spec`
- `0002-003-bilingual-readme-ai-native`
- `0002-004-work-model-reorganization`
- `0002-005-github-actions-node24`

Delivered:

- Project map and architecture boundaries.
- Self-contained AI handoff docs.
- Workflow, task protocol, extension playbooks, and registry.
- Epic / Task / Step work model.
- GitHub Actions checkout action updated for Node.js 24.
- English and Simplified Chinese README files.
- AI-native development model documentation.

### 0003 Routing Macro System

Status: implemented

Tasks:

- `0003-001-macro-route-mvp`
- `0003-002-group-macro-mvp`

Delivered:

- `@DaylilyServer`
- `@GET`
- `@POST`
- `@GROUP`
- Macro lowering into runtime route DSL.

### 0004 JSON System

Status: implemented

Tasks:

- `0004-001-json-body-and-response`

Delivered:

- `DaylilyJSON` module.
- `request.body.json(Type.self, upTo:)`.
- `request.json(Type.self)` convenience sugar.
- `JSON(value)` response wrapper.
- `content-type: application/json` response header.
- Example JSON routes and behavior checks.

### 0008 Body System

Status: implemented

Tasks:

- `0008-001-body-model-migration`
- `0008-002-nio-true-streaming-bridge`

Delivered:

- `Request.body: RequestBody`.
- One-shot body consumption.
- `BodyBytes` with `ByteChunk`.
- `ByteCount` units for bytes, kilobytes, megabytes, and gigabytes.
- Async JSON body decoding.
- 413 `Payload Too Large` body limit mapping.
- NIO true streaming body bridge.
- Bounded buffering and practical NIO `autoRead` backpressure.
- Chunked upload smoke route.

### 0009 Middleware System

Status: implemented

Tasks:

- `0009-001-middleware-runtime`
- `0009-002-explicit-buffered-body-helper`

Delivered:

- Runtime middleware pipeline.
- Application, group, and route middleware scopes.
- Public `Middleware` protocol.
- `Routes` group collection wrapper.
- Define ordering, short-circuiting, and error behavior.
- Let application middleware wrap missing-route responses.
- Make body interaction explicit: middleware may read `RequestBody`, but it consumes the one-shot stream.
- Checks for ordering, same-scope order, group scope, 404 wrapping, short-circuiting, thrown errors, path parameters, and body one-shot behavior.
- Explicit `Request.withBufferedBody(upTo:_:)`.
- Keep helper in `DaylilyCore` first.
- Preserve one-shot replacement bodies.
- Require an explicit `ByteCount` limit.
- Avoid automatic body replay and hidden middleware buffering.

## Core Experience Phase

Goal:

- Move Daylily from "can run" to "has its own style."
- Prioritize the feel of writing and testing Daylily apps before ecosystem expansion.

Principles:

- Do not start Fluent, Redis, Jobs, or broad ecosystem packages yet.
- Build typed handler inputs first.
- Add testing support early so AI and humans can verify new behavior cleanly.
- Add lifecycle before database pools, workers, and production integrations.

Recommended sequence:

```text
0010 Typed Handler Inputs
0011 DaylilyTesting
0012 Lifecycle / Server Controls
0013 Observability Middleware
0014 OpenAPI Metadata
```

Practical interleave:

```text
0010-001 Typed path extraction runtime (delivered)
0010-002 @Path macro MVP (delivered)
0011-001 DaylilyTesting minimal TestClient (delivered)
0011-002 DaylilyTesting request builders and JSON assertions (delivered)
0010-003 @JSONBody macro/runtime bridge (delivered)
0010-004 @Query / @Header (delivered)
0012-001 Application lifecycle MVP (delivered)
0012-002 Graceful shutdown (delivered)
0012-003 Server configuration (delivered)
0013-001 Request logging middleware (delivered)
0013-002 Request ID and timing (delivered)
0014-001 Route metadata runtime (delivered)
0014-002 OpenAPI schema MVP (delivered)
0014-003 Macro metadata bridge (delivered)
0017-001 True @Body input spelling (delivered)
```

## Recently Completed Epic

### 0010 Typed Handler Inputs

Status: implemented

Delivered:

- `0010-001-typed-path-extraction-runtime`
- `0010-002-path-macro-mvp`
- `0010-003-body-json-macro-runtime-bridge`
- `0010-004-query-and-header-inputs`

Delivered shape:

```swift
@GET("/users/:id")
func user(@Path id: Int) -> String

@POST("/users")
func create(@Body input: CreateUserInput) async throws -> Status

@GET("/search")
func search(
    @Query term: String,
    @Header("x-daylily") token: String
) -> String
```

### 0012 Lifecycle / Server Controls

Status: implemented

Delivered:

- `0012-001-application-lifecycle-mvp`
- `0012-002-graceful-shutdown`
- `0012-003-server-configuration`

Delivered shape:

```swift
let app = Application {
    Get("/hello") { "ok" }
}
.boot { ... }
.started { ... }
.shutdown { ... }
.cleanup { ... }
```

Follow-up:

- Observability and OpenAPI slices are now delivered.
- The next work should move into the beta closure sequence.

### 0013 Observability Middleware

Status: in-progress

Delivered:

- `0013-001-request-logging-middleware`
- `0013-002-request-id-and-timing`

Delivered shape:

```swift
let app = Application {
    Get("/hello") { request in
        request.daylilyRequestID ?? "missing"
    }
}
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

Delivered request identity shape:

- `requestID` is a Daylily-generated `dl_<UUID>`, unique per request inside this service.
- `correlationID` is external `x-request-id`, optional and not guaranteed unique.

Response header behavior:

```text
always write x-daylily-request-id
preserve incoming x-request-id when present
write generated requestID to x-request-id only when no incoming x-request-id exists
```

Remaining future slices:

- observability hooks

### 0014 OpenAPI Metadata

Status: implemented

Delivered:

- `0014-001-route-metadata-runtime`
- `0014-002-openapi-schema-mvp`
- `0014-003-macro-metadata-bridge`

Delivered shape:

```swift
Get("/users/:id") {
    "ok"
}
.describe(
    summary: "Show user",
    tags: ["Users"],
    inputs: [.path("id", type: "Int")]
)

let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
```

Macro typed inputs now lower into route metadata:

```text
@Path -> RouteInputMetadata.path(...)
@Query -> RouteInputMetadata.query(...)
@Header -> RouteInputMetadata.header(...)
@Body -> RouteBodyMetadata.json(...)
@JSONBody -> RouteBodyMetadata.json(...) compatibility alias spelling
```

Suggested next task:

- Continue Package Consumer Experience with the first real API example.

## Beta Closure Sequence

Goal:

- Close the minimum beta capability loop before ecosystem packages.

Recommended sequence:

```text
0015-001 Runtime and testing HTTP verbs: PUT / PATCH / DELETE / HEAD / OPTIONS (delivered)
0015-002 Macro and OpenAPI HTTP verbs: @PUT / @PATCH / @DELETE / @HEAD / @OPTIONS (delivered)
0016-001 Formal test target (delivered)
0017-001 True @Body input spelling (delivered)
0018-001 Beta docs: quickstart, examples, capability matrix (delivered)
0019-001 Release hygiene: Linux CI, CHANGELOG, semver tag strategy, public API registry sync (delivered)
0019-002 Alpha release: first public SwiftPM prerelease (delivered)
0020-001 External consumer smoke test: path and release package modes (delivered)
0020-002 Minimal app template: recommended external project shape (delivered)
```

### 0015 HTTP Verbs Beta Closure

Status: implemented

Delivered:

- `0015-001-runtime-and-testing-http-verbs`
- `0015-002-macro-and-openapi-http-verbs`

Delivered runtime shape:

```swift
Put("/users/:id") { request in ... }
Patch("/users/:id") { request in ... }
Delete("/users/:id") { Status.noContent }
Head("/health") { Status.ok }
Options("/health") { Status.noContent }
```

Remaining:

- `0.1.0-alpha.1` is the first public alpha release after macOS and Linux CI are green.
- Next package consumer slice is the first real API example.

## Package Consumer Experience

Goal:

- Make Daylily reliable and comfortable as a third-party SwiftPM dependency.

Sequence:

```text
0020-001 External SwiftPM consumer smoke test (delivered)
0020-002 Minimal app template (delivered)
0020-003 First real API example (planned)
0020-004 Dependency injection design (planned)
0020-005 DI runtime MVP (planned)
```

Delivered:

- `scripts/consumer-smoke-test.sh` creates a fresh external SwiftPM package.
- Path mode validates the current checkout as a pre-release gate.
- Release mode validates the published `0.1.0-alpha.1` package path.
- The generated consumer package compiles runtime DSL and macro executable targets.
- The generated consumer package runs Swift Testing with `DaylilyTesting`.
- `templates/minimal-app` defines the recommended `AppCore` plus `App` executable shape.
- `scripts/template-smoke-test.sh` validates the template in path and release dependency modes.

### Future Epics

- Future ecosystem packages after Daylily's core experience stabilizes.

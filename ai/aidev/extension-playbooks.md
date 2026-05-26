# Extension Playbooks

Use these recipes when extending Daylily.

## Add an HTTP Verb

Example: add `Put`.

Steps:

1. Confirm `HTTPMethod` already has the method. If not, add it.
2. Add runtime DSL overloads in `Route.swift`.
3. Add checks in `HelloDaylily --check`.
4. Update `api-registry.md`.
5. Update `registry.yml`.
6. Run validation commands.

Do not touch NIO transport unless the method cannot be parsed.

## Add Typed Path Extraction

Current shape:

```swift
let id = try request.parameters.require("id", as: Int.self)
let maybePage = try request.parameters.get("page", as: Int.self)
```

Rules:

1. Keep runtime extraction in `DaylilyCore`.
2. Add macro sugar only after runtime behavior exists.
3. Missing or invalid values must map to `400 Bad Request`.
4. Error reasons must name the parameter and expected type.
5. Do not add Foundation-backed types such as `UUID` without a deliberate design decision.
6. Keep query/header/body extraction out of the first typed path task.

To add a new standard-library parameter type:

1. Conform the type to `ParameterDecodable`.
2. Add checks for success and invalid input.
3. Update `api-registry.md` and `registry.yml`.

## Extend Path Macro Injection

Current shape:

```swift
@GET("/users/:id")
func user(@Path id: Int) -> String

@GET("/accounts/:id")
func account(@Path("id") accountID: Int) -> String
```

Rules:

1. Keep `@Path` as a marker. Extraction stays in `Parameters.require(_:as:)`.
2. Keep `@DaylilyServer` responsible for lowering handler parameters.
3. Validate that every `@Path` name exists as a `:name` segment in the full route path.
4. Preserve existing zero-parameter and `Request` handler support.
5. Add compile-time macro smoke coverage for new handler shapes.
6. Do not add `@Body`, `@Query`, `@Header`, or optional path values in this playbook.

## Extend JSON Body Decoding

Current shape:

```swift
let input = try await request.body.json(CreateUser.self, upTo: .megabytes(1))
let input = try await request.json(CreateUser.self)
```

Implemented owner: `DaylilyJSON`.

Steps:

1. Keep Foundation-based JSON helpers in `DaylilyJSON`.
2. Do not move JSON into `DaylilyCore` without an ADR.
3. Keep `request.body.json(...)` as the standard API.
4. Keep `request.json(...)` as convenience sugar with a default 1 MB limit.
5. Enforce explicit body limits for standard body helpers.
6. Preserve `Abort(.badRequest, reason: "Invalid JSON body")` for decode failures unless the error model is intentionally revised.
7. Add checks.
8. Update API registry and conventions.

Non-goals:

- streaming JSON
- multipart
- validation framework

## Extend JSON Responses

Current shape:

```swift
struct User: Codable { ... }

Get("/user") {
    JSON(User(...))
}
```

Risk:

Swift cannot safely make all `Encodable` automatically conform to `ResponseConvertible` without careful generic design.

Implemented first step:

```swift
JSON(User(...))
```

Steps:

1. Preserve the explicit JSON response wrapper.
2. Set `content-type: application/json` unless already provided.
3. Encode errors should become 500 through `Application.respond(to:)` unless explicitly user-caused.
4. Add checks.
5. Update AIDEV.

## Add Middleware Runtime

Current state:

- 0009-001 implemented runtime middleware.
- Public protocol: `Middleware`.
- Scopes: application, group, route.
- Order: application -> router dispatch -> group -> route -> handler.
- No automatic body replay.

Goal shape:

```swift
Application {
    Group("/api") {
        Get("/health") { "ok" }
    }
    .middleware(Auth())
}
```

Design first:

```swift
protocol Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response
}
```

Steps:

1. Add runtime middleware concept before macros.
2. Define ordering: application -> router dispatch -> group -> route -> handler.
3. Preserve declaration order within a scope.
4. Allow short-circuiting by returning a response without calling `next`.
5. Let thrown middleware errors flow through existing `Application.respond(to:)` error mapping.
6. Add checks for order, short-circuiting, missing-route wrapping, thrown errors, and body consumption.
7. Update route/group/application contracts.
8. Only then design `@Use` or macro sugar.

Body rules:

1. Middleware may read `request.body`.
2. `request.body` remains one-shot.
3. If middleware consumes the body and calls `next`, downstream code sees the consumed body.
4. Do not add automatic body replay in the first middleware task.
5. If downstream code needs an equivalent body, use `request.withBufferedBody(upTo:_:)` deliberately.
6. `withBufferedBody(upTo:_:)` buffers in memory under a required limit and creates a one-shot replacement body.

## Add Explicit Buffered Body Helper

Current state:

- 0009-002 implemented `Request.with(body:)`.
- 0009-002 implemented `Request.withBufferedBody(upTo:_:)`.
- The helper lives in `DaylilyCore`.
- The replacement body is `Body.bytes(collectedBytes)`.
- The replacement body remains one-shot.
- No hidden or automatic body replay exists.

Rules:

1. Keep `upTo:` required.
2. Preserve `BodyError.tooLarge -> 413 Payload Too Large`.
3. Do not move this into JSON/Content until those layers exist.
4. Do not add file-backed buffering or multipart behavior in this helper.
5. Keep the API name explicit about buffering.

## Add Streaming Body

Goal shape:

```swift
for try await chunk in request.body.bytes {
    ...
}
```

Rules:

1. Do not expose `ByteBuffer` publicly by default.
2. Preserve backpressure.
3. Keep transport stream construction behind `@_spi(Transport)`.
4. Do not keep buffering large bodies in memory.
5. Define cancellation behavior.
6. Preserve one-shot consumption behavior.

Current state:

- 0008-001 introduced the Daylily-owned `Body` model.
- 0008-002 implemented true NIO chunk feeding, bounded buffering, cancellation, and practical backpressure.

Extension steps:

1. Reuse `request.body.bytes` as the public surface.
2. Add helpers on top of `Body` rather than exposing transport details.
3. Preserve `BodyError.tooLarge` and `BodyError.streamFailed` mappings.
4. Add checks with chunked input when changing transport behavior.
5. Update AIDEV thoroughly.

## Extend Macro Route MVP

Current implemented shape:

```swift
@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GROUP("/api")
    struct API {
        @GET("/health")
        func health() -> String { "ok" }
    }
}
```

When extending:

1. Keep macro output lowering into runtime DSL.
2. Keep runtime DSL working.
3. Add compile-time smoke coverage.
4. Add checks where runtime behavior changes.
5. Update AIDEV and registry.

Still non-goals until separate tasks:

- true `@Body` spelling
- `@Query`
- `@Header`
- OpenAPI
- DI

## Extend JSON Body Macro Injection

Current shape:

```swift
@POST("/users")
func create(@JSONBody input: CreateUserInput) async throws -> Status
```

Rules:

1. Keep `@JSONBody` as a marker in `DaylilyJSON`.
2. Lower into `try await req.json(Type.self)`.
3. Preserve runtime JSON behavior and error mapping.
4. Allow at most one `@JSONBody` parameter per handler.
5. Do not rename this to `@Body` until the raw `Body` type naming decision is revisited.
6. Add macro smoke coverage for top-level and grouped handlers.

## Add a New Transport

Examples:

- test transport
- Lambda transport
- Network.framework transport

Rules:

1. New transport depends on `DaylilyCore`.
2. It converts external request representation into Daylily `Request`.
3. It converts Daylily `Response` back into external response representation.
4. It must not require changes to handlers.
5. It should not become a dependency of `DaylilyCore`.

## Extend DaylilyTesting

Current shape:

```swift
let response = try await TestClient(app).get("/hello")
try response.requireStatus(.ok)

let request = try TestRequest.post("/json/echo").withJSON(input)
let jsonResponse = try await TestClient(app).send(request)
try jsonResponse.requireJSON(expected)
```

Rules:

1. Keep testing helpers in `DaylilyTesting`.
2. Keep `DaylilyTesting` transport-free.
3. Do not add NIO dependencies to `DaylilyTesting`.
4. Reuse `Application.respond(to:)` for in-memory behavior.
5. Keep request construction as Daylily `Request`/`Body` sugar rather than a separate transport model.
6. Add `HelloDaylily --check` coverage until a dedicated Swift test target exists.

## Add Checks

Current check host:

```text
Sources/HelloDaylily/Checks.swift
```

Steps:

1. Add a focused in-memory check using `TestClient` or `Application.respond(to:)`.
2. Use clear failure messages.
3. Keep checks fast.
4. If adding server behavior, smoke test manually with `curl`.

Future:

- Add a dedicated Swift test target once the project chooses `XCTest` or Swift Testing.

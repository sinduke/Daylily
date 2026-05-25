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
2. Define ordering: global -> group -> route -> handler.
3. Add checks for order and short-circuiting.
4. Update route/group contracts.
5. Only then design `@Use` or macro sugar.

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
3. Do not claim true streaming while the transport still buffers.
4. Do not keep buffering large bodies in memory in the final streaming bridge.
5. Define cancellation behavior.
6. Preserve one-shot consumption behavior.

Current split:

- 0008A introduced the Daylily-owned `Body` model.
- 0008B must implement true NIO chunk feeding, bounded buffering, and backpressure.

0008B likely steps:

1. Create request after NIO request head.
2. Feed NIO body chunks into `BodyBytes`.
3. Finish stream on request end.
4. Fail stream on channel/protocol error.
5. Add checks with chunked input.
6. Update AIDEV thoroughly.

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

- `@Path`
- `@Body`
- OpenAPI
- DI

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

## Add Checks

Current check host:

```text
Sources/HelloDaylily/Checks.swift
```

Steps:

1. Add a focused in-memory check using `Application.respond(to:)`.
2. Use clear failure messages.
3. Keep checks fast.
4. If adding server behavior, smoke test manually with `curl`.

Future:

- Add a proper test target once the environment supports `XCTest` or Swift Testing.

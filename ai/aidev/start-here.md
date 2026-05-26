# Start Here

This is the first file an AI should read when taking over Daylily.

## What Daylily Is

Daylily is an experimental AI-native web framework for Swift.

Its intended surface is macro-driven and declarative:

```swift
@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }
}
```

Current implemented surfaces are the runtime DSL, runtime middleware, the Daylily-owned `Body` model, JSON body/response helpers, and the macro route/group MVP.

Runtime DSL:

```swift
import Daylily

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable {
    let echo: String
}

struct HeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-daylily"] = "ships"
        return response
    }
}

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }

    Get("/users/:id") { request in
        "User \(request.parameters.id ?? "unknown")"
    }

    Post("/json/echo") { request in
        let input = try await request.json(EchoPayload.self)
        return JSON(EchoResponse(echo: input.message))
    }

    Post("/echo") { request in
        try await request.body.string(upTo: .kilobytes(64))
    }
    .middleware(HeaderMiddleware())
}
.middleware(HeaderMiddleware())

try await app.run()
```

Middleware order is:

```text
application -> router dispatch -> group -> route -> handler
```

Middleware may read `request.body`, but `Body` is one-shot. There is no hidden body replay.

Macro route/group MVP:

```swift
@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(req: Request) -> String {
        "User \(req.parameters.id ?? "unknown")"
    }

    @GROUP("/api")
    struct API {
        @GET("/health")
        func health() -> String {
            "ok"
        }
    }
}
```

The macro layer lowers into the runtime DSL.

## Current Stage

Implemented:

- Swift package.
- Core runtime.
- Basic route DSL: `Get`, `Post`, `Group`.
- Runtime middleware at application, group, and route scope.
- Macro route/group MVP: `@DaylilyServer`, `@GET`, `@POST`, `@GROUP`.
- Daylily-owned `Body` model with one-shot consumption.
- `ByteChunk`, `BodyBytes`, `ByteCount`, `BodyError`, and `ResponseError`.
- True NIO request body streaming bridge with bounded buffering and practical backpressure.
- Async JSON body decoding with `request.body.json(...)` and `request.json(...)`.
- JSON responses with `JSON(...)`.
- Request and response types.
- Path parameter extraction as strings.
- NIO-backed HTTP server.
- Default `swift run` executable.
- Lightweight behavior checks.
- AIDEV project contract.

Not implemented:

- Typed parameter injection.
- OpenAPI.
- Dependency injection.
- Macro middleware attributes.
- Real test target.

## Read Order

Read these before planning or modifying:

1. `AIDEV.md`
2. `ai/aidev/start-here.md`
3. `ai/aidev/invariants.md`
4. `ai/aidev/architecture.md`
5. `ai/aidev/runtime-contracts.md`
6. `ai/aidev/api-registry.md`
7. `ai/aidev/extension-playbooks.md`
8. `ai/aidev/task-protocol.md`
9. `ai/aidev/registry.yml`

For implementation work, also read the relevant epic in `ai/epics/` and task file in `ai/tasks/`.

Current work hierarchy:

- Epics are themes and live in `ai/epics/`.
- Tasks are the smallest commit/push unit and live in `ai/tasks/`.
- Steps live inside task files as checklists and must not be committed or pushed independently.

## Source Reading Policy

AIDEV is the authoritative map.

AI should not need to inspect source code to understand:

- what the project is
- how modules relate
- what public APIs exist
- how requests flow
- what invariants must hold
- how to extend the framework

When actually editing files, reading the target file is allowed for mechanical accuracy. Do not use source reading to invent a new architecture if AIDEV already defines the rule.

## Required Commands

Always verify with:

```sh
swift build
swift run HelloDaylily --check
```

If server behavior changed, also run:

```sh
swift run
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

Stop the server after smoke testing.

## Do Not Do Yet

Do not start with:

- ORM
- database module
- auth
- OpenAPI
- production middleware stack
- benchmarking suite

Current strategic order:

1. Keep AIDEV self-contained.
2. Add typed parameter extraction.
3. Add OpenAPI metadata.

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

Current implemented surfaces are the runtime DSL, JSON body/response helpers, and the macro route/group MVP.

Runtime DSL:

```swift
import Daylily

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable {
    let echo: String
}

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }

    Get("/users/:id") { request in
        "User \(request.parameters.id ?? "unknown")"
    }

    Post("/json/echo") { request in
        let input = try request.json(EchoPayload.self)
        return JSON(EchoResponse(echo: input.message))
    }
}

try await app.run()
```

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
- Macro route/group MVP: `@DaylilyServer`, `@GET`, `@POST`, `@GROUP`.
- JSON body decoding with `request.json(...)`.
- JSON responses with `JSON(...)`.
- Request and response types.
- Path parameter extraction as strings.
- NIO-backed HTTP server.
- Default `swift run` executable.
- Lightweight behavior checks.
- AIDEV project contract.

Not implemented:

- Middleware.
- Streaming body.
- Typed parameter injection.
- OpenAPI.
- Dependency injection.
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

For an implementation task, also read the relevant task file in `ai/tasks/`.

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
2. Add streaming body.
3. Add middleware.
4. Add typed parameter extraction.

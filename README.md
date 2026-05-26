# Daylily

English | [简体中文](README.zh-CN.md)

[![CI](https://github.com/sinduke/Daylily/actions/workflows/ci.yml/badge.svg)](https://github.com/sinduke/Daylily/actions/workflows/ci.yml)

Daylily is an experimental AI-native web framework for Swift.

It starts small on purpose: a declarative runtime, a NIO-backed HTTP server, and an AIDEV contract that lets AI agents understand, use, upgrade, and extend the project without first spelunking through source code.

> Still waiting? Daylily already shipped.

## Why Daylily

Server-side Swift has strong foundations, but framework evolution can feel slow and opaque. Daylily takes a different path:

- Build the runtime first.
- Keep the core small.
- Hide transport details from user APIs.
- Make Swift Concurrency the default model.
- Use macros as declaration sugar, not as the source of truth.
- Let AI participate in the project through explicit architecture maps, contracts, registries, tasks, and playbooks.

Daylily is not trying to be a clone of Vapor or Hummingbird. It is an experiment in what a Swift web framework can look like when AI-assisted development is part of the architecture from day one.

## Current Status

Implemented today:

- Swift package skeleton.
- `Application` runtime.
- Declarative route DSL: `Get`, `Post`, `Group`.
- Path parameters with `:name` syntax.
- `Request`, `Response`, `Status`, `Headers`, `Parameters`.
- Daylily-owned `Body` request body model.
- One-shot body consumption with `ByteChunk` and `ByteCount`.
- True NIO request body streaming bridge with bounded buffering and practical backpressure.
- Runtime middleware with application, group, and route scopes.
- Explicit `withBufferedBody(upTo:_:)` helper for bounded body inspection and replacement.
- `ResponseConvertible` for `String`, `Status`, and `Response`.
- Async JSON body decoding with `request.body.json(...)` and `request.json(...)`.
- JSON responses with `JSON(...)`.
- NIO-backed HTTP/1.1 server.
- Macro route/group MVP: `@DaylilyServer`, `@GET`, `@POST`, `@GROUP`.
- Default `swift run` example server.
- Lightweight behavior checks.
- AIDEV project handoff system.

Not implemented yet:

- Typed parameter injection.
- OpenAPI generation.
- Dependency injection.
- Macro middleware attributes.

## Quick Start

From the project root:

```sh
swift build
swift run HelloDaylily --check
swift run
```

The server listens on:

```text
http://127.0.0.1:8080
```

Try it:

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/users/42
curl -X POST --data 'hi' http://127.0.0.1:8080/echo
printf 'abcdef' | curl --http1.1 -H 'Transfer-Encoding: chunked' -H 'Content-Length:' --data-binary @- http://127.0.0.1:8080/upload/count
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## Current API

The current runtime API looks like this:

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable {
    let echo: String
}

@main
struct HelloDaylily {
    static func main() async throws {
        let app = Application {
            Get("/") {
                "Daylily is awake."
            }

            Get("/hello") {
                "Daylily ships."
            }

            Get("/users/:id") { request in
                "User \(request.parameters.id ?? "unknown")"
            }

            Get("/json/health") {
                JSON(HealthPayload(status: "ok"))
            }

            Post("/json/echo") { request in
                let input = try await request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }

            Post("/echo") { request in
                try await request.body.string(upTo: .kilobytes(64))
            }
        }

        try await app.run()
    }
}
```

## Runtime Middleware

Middleware is available at application, group, and route scope:

```swift
struct HeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-daylily"] = "ships"
        return response
    }
}

let app = Application {
    Group("/api") {
        Get("/health") {
            "ok"
        }
    }
    .middleware(HeaderMiddleware())

    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(HeaderMiddleware())
```

Order is:

```text
application -> router dispatch -> group -> route -> handler
```

Middleware can read `request.body`, but `Body` is one-shot. If middleware consumes the body and then calls `next`, downstream code sees the body as already consumed. Daylily does not perform hidden body replay.

When middleware intentionally needs to inspect body bytes and still pass an equivalent body downstream, use explicit buffering:

```swift
struct SignatureMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await request.withBufferedBody(upTo: .megabytes(1)) { replayed, bytes in
            try verify(bytes)
            return try await next.respond(to: replayed)
        }
    }
}
```

The replacement body is still one-shot, and the helper requires an explicit size limit.

## Macro API MVP

Daylily's macro MVP supports this shape:

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

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

    @GET("/health")
    func health() -> JSON<HealthPayload> {
        JSON(HealthPayload(status: "ok"))
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

The rule is simple: macros must lower into the runtime route system. The runtime remains the source of truth.

MVP limits:

- handlers must be instance methods;
- the server type must be default-initializable with `Self()`;
- handlers may have zero parameters or one `Request` parameter;
- grouped types must be default-initializable;
- `@Path`, `@Body`, macro middleware attributes, DI, and OpenAPI are future work.

## AI-Native Development

Daylily is designed so an AI agent can become useful quickly.

Instead of asking AI to guess the architecture from scattered source files, the project contains an explicit AIDEV system:

- [AIDEV.md](AIDEV.md): the main AI development entry point.
- [ai/aidev/start-here.md](ai/aidev/start-here.md): the first file an AI should read.
- [ai/aidev/project-map.md](ai/aidev/project-map.md): modules, files, and responsibilities.
- [ai/aidev/architecture.md](ai/aidev/architecture.md): dependency direction and boundary rules.
- [ai/aidev/runtime-contracts.md](ai/aidev/runtime-contracts.md): component inputs, outputs, guarantees, and extension points.
- [ai/aidev/api-registry.md](ai/aidev/api-registry.md): current public API surface.
- [ai/aidev/extension-playbooks.md](ai/aidev/extension-playbooks.md): recipes for adding verbs, JSON, middleware, streaming body, macros, transports, and checks.
- [ai/epics](ai/epics): theme-level planning containers.
- [ai/tasks](ai/tasks): task-level execution records; tasks are the smallest commit/push unit.
- [ai/aidev/registry.yml](ai/aidev/registry.yml): machine-readable project registry.
- [ai/prompts/daylily-agent.md](ai/prompts/daylily-agent.md): reusable prompt for future AI agents.

This means a user can ask an AI to:

- explain how Daylily works;
- add a new HTTP verb;
- extend JSON support;
- design middleware;
- implement macros;
- update the public API registry;
- write or update checks;
- validate the project with the known commands.

The AI does not need to rediscover the project from scratch. It starts from the AIDEV contract, makes a scoped change, updates the contract if needed, and runs validation.

## Project Layout

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
│   ├── DaylilyNIO/
│   └── HelloDaylily/
└── ai/
    ├── epics/
    ├── aidev/
    ├── prompts/
    └── tasks/
```

## Architecture Rules

The most important invariants:

- `DaylilyCore` must not depend on NIO.
- User-facing APIs must not expose NIO types.
- Runtime APIs come before macro sugar.
- `swift run` should keep starting the example server.
- `swift run HelloDaylily --check` should keep passing.
- Public API changes must update AIDEV.

## Roadmap

Near-term:

1. Typed parameter extraction.
2. OpenAPI metadata.
3. Request context and production server controls.

## License

Daylily is released under the [MIT License](LICENSE).

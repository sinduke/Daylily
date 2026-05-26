<div align="center">

# Daylily

### Modern AI-first Swift web framework

Built for the Swift Concurrency era.<br>
Designed for humans and AI agents together.

[English](README.md) | [简体中文](README.zh-CN.md)

[Documentation](docs/README.md) •
[Quick Start](#quick-start) •
[Detailed Usage Guide](#detailed-usage-guide) •
[AI-Native](#ai-native-by-design) •
[Architecture](#architecture) •
[Roadmap](#roadmap)

[![CI](https://github.com/sinduke/Daylily/actions/workflows/ci.yml/badge.svg)](https://github.com/sinduke/Daylily/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20Linux%20CI-blue)
![Concurrency](https://img.shields.io/badge/Concurrency-Native-green)
![OpenAPI](https://img.shields.io/badge/OpenAPI-MVP-8A2BE2)
![Status](https://img.shields.io/badge/status-Experimental-red)

</div>

---

## Why Daylily Exists

Server-side Swift has powerful foundations.

But many frameworks still feel shaped by the pre-Concurrency era:

- EventLoop-heavy application code.
- Transport details leaking into user-facing APIs.
- Runtime patterns optimized for frameworks, not products.
- Architecture that AI agents must reverse-engineer from source.
- Macro-first designs where the runtime truth is hard to inspect.

Daylily takes another path:

- Swift Concurrency first.
- Runtime-first architecture.
- AI-native development workflow.
- Explicit contracts over hidden magic.
- Product-oriented developer experience.

Daylily starts small on purpose: a declarative runtime, a NIO-backed HTTP/1.1 server, and an AIDEV contract that lets AI agents understand, use, upgrade, and extend the project without first spelunking through source code.

## Hello World

```swift
import Daylily

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }
}
```

That's it.

## Core Philosophy

### AI-Native by Design

Daylily is built so AI agents can safely understand and extend projects.

Instead of forcing AI to infer architecture from source code alone, Daylily exposes:

- architecture contracts;
- API registries;
- runtime guarantees;
- extension playbooks;
- project maps;
- machine-readable metadata.

AI becomes a first-class development participant.

### Runtime First

Macros are tools. Runtime truth matters more.

Daylily prioritizes:

- observable runtime state;
- explicit contracts;
- deterministic architecture;
- introspection-friendly systems.

### Swift Concurrency First

Daylily is designed around modern Swift:

- `async` / `await`;
- `Sendable`;
- structured concurrency;
- transport boundaries that stay out of user-facing APIs.

## Feature Matrix

| Area | Status |
| --- | --- |
| Swift Concurrency-native runtime | Implemented |
| Declarative route DSL | Implemented |
| Macro route/group declarations | MVP |
| Typed path/query/header inputs | Implemented |
| Typed JSON body input with `@Body` | Implemented |
| Middleware | Implemented |
| Streaming request body | Implemented |
| JSON body and response helpers | Implemented |
| OpenAPI generation | MVP |
| Observability middleware | MVP |
| Transport-free testing helpers | Implemented |
| AIDEV AI handoff system | Implemented |
| Dependency injection | Planned |
| Macro middleware attributes | Planned |
| Full Swift schema derivation | Planned |

## Architecture

```text
Client / SwiftUI / Flutter / API Consumer
        |
        v
Shared DTOs and HTTP contracts
        |
        v
Daylily Runtime
        |
        +--> Route metadata --> OpenAPI
        |
        +--> AIDEV contracts --> AI agents
        |
        v
Transport layer
```

The runtime remains the source of truth. Macros lower into runtime routes and metadata; OpenAPI and AI tooling read the same explicit contract instead of guessing from source code.

## Benchmarks

Benchmarks are in progress.

The current focus is:

- predictable architecture;
- concurrency correctness;
- developer experience;
- AI collaboration;
- long-term maintainability.

Raw performance benchmarks will be published after the runtime and beta documentation stabilize.

## Ecosystem Vision

Daylily is evolving toward a Swift cloud development experience, not only a routing library.

Potential ecosystem directions:

- authentication;
- realtime features;
- queues and background jobs;
- deployment tooling;
- AI-assisted architecture workflow;
- fullstack Swift patterns.

## Quick Start

Use Daylily as a SwiftPM package:

```swift
.package(url: "https://github.com/sinduke/Daylily.git", from: "0.1.0-alpha.1")
```

Add the product to your target:

```swift
.product(name: "Daylily", package: "Daylily")
```

For local framework development or examples, run from source.

From the project root:

```sh
swift build
swift test
swift run HelloDaylily --check
swift run
```

To verify Daylily from a fresh external SwiftPM package:

```sh
scripts/consumer-smoke-test.sh --mode path
scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

To start from the recommended minimal app shape:

```sh
cp -R templates/minimal-app MyDaylilyApp
cd MyDaylilyApp
swift build
swift test
swift run App --check
```

To try the first real API example:

```sh
scripts/example-smoke-test.sh --mode path
cd examples/commerce-api
swift run App --check
swift run App
```

Daylily uses Swift Testing for the formal test target. If `swift test` reports `no such module 'Testing'` while `xcode-select -p` points at Command Line Tools, run it with an Xcode developer directory, for example:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
```

The server listens on:

```text
http://127.0.0.1:8080
```

Try it:

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/users/42
curl 'http://127.0.0.1:8080/search?term=daylily&page=1'
curl -H 'x-daylily: ships' http://127.0.0.1:8080/headers
curl -X POST --data 'hi' http://127.0.0.1:8080/echo
curl -X PUT --data 'full' http://127.0.0.1:8080/users/42
curl -X PATCH --data 'partial' http://127.0.0.1:8080/users/42
curl -i -X DELETE http://127.0.0.1:8080/users/42
curl -I http://127.0.0.1:8080/health
curl -i -X OPTIONS http://127.0.0.1:8080/health
printf 'abcdef' | curl --http1.1 -H 'Transfer-Encoding: chunked' -H 'Content-Length:' --data-binary @- http://127.0.0.1:8080/upload/count
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## Detailed Usage Guide

The rest of this README is the detailed usage guide. It keeps the concrete, copy-pasteable examples close to the project entry point.

Dedicated beta docs are also available:

- [Documentation hub](docs/README.md)
- [Quick Start](docs/quickstart.md)
- [Capability Matrix](docs/capability-matrix.md)
- [Release Readiness](docs/release-readiness.md)
- [Commerce API Example](docs/examples/commerce-api.md)
- [JSON API Example](docs/examples/json-api.md)
- [Middleware Example](docs/examples/middleware.md)
- [Testing Example](docs/examples/testing.md)

README sections:

- [Current API](#current-api): runtime routes, typed parameters, JSON, lifecycle, and server configuration.
- [Runtime Middleware](#runtime-middleware): application, group, and route middleware with one-shot body rules.
- [Observability](#observability): request ID and request logging middleware.
- [Route Metadata](#route-metadata): explicit metadata and minimal OpenAPI generation.
- [DaylilyTesting](#daylilytesting): in-memory tests, request builders, and JSON assertions.
- [Macro API MVP](#macro-api-mvp): `@DaylilyServer`, route macros, typed inputs, and macro limits.
- [AI-Native Development](#ai-native-development): AIDEV contracts, registries, playbooks, and agent workflow.

## Current API

The current runtime API looks like this:

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

struct CreateUserInput: Codable, Sendable {
    let name: String
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
                let id = try request.parameters.require("id", as: Int.self)
                return "User \(id)"
            }

            Get("/search") { request in
                let term = try request.query.require("term", as: String.self)
                let page = try request.query.get("page", as: Int.self) ?? 1
                return "Search \(term) page \(page)"
            }

            Get("/headers") { request in
                try request.headers.require("x-daylily", as: String.self)
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

            Put("/users/:id") { request in
                let id = try request.parameters.require("id", as: Int.self)
                let body = try await request.body.string(upTo: .kilobytes(64))
                return "Updated user \(id): \(body)"
            }

            Patch("/users/:id") { request in
                let id = try request.parameters.require("id", as: Int.self)
                let body = try await request.body.string(upTo: .kilobytes(64))
                return "Patched user \(id): \(body)"
            }

            Delete("/users/:id") {
                Status.noContent
            }

            Head("/health") {
                Status.ok
            }

            Options("/health") {
                Status.noContent
            }
        }

        try await app.run()
    }
}
```

Lifecycle hooks are available before ecosystem modules:

```swift
let app = Application {
    Get("/hello") { "ok" }
}
.configure {
    // register configuration
}
.boot {
    // open resources
}
.started {
    // server has bound successfully
}
.shutdown {
    // stop accepting work
}
.cleanup {
    // release resources
}
```

Explicit server configuration is available when defaults are not enough:

```swift
try await app.run(
    configuration: ServerConfiguration(
        host: "0.0.0.0",
        port: 8080
    )
)
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

Middleware can read `request.body`, but `RequestBody` is one-shot. If middleware consumes the body and then calls `next`, downstream code sees the body as already consumed. Daylily does not perform hidden body replay.

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

## Observability

`DaylilyObservability` provides request ID and request logging middleware without adding logging backends or tracing dependencies to `DaylilyCore`:

```swift
let app = Application {
    Get("/hello") { request in
        request.daylilyRequestID ?? "missing"
    }
}
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

`RequestIDMiddleware` always generates a Daylily-owned `x-daylily-request-id`. Incoming `x-request-id` is treated as external correlation data, not as Daylily's unique request identity. When no incoming `x-request-id` exists, Daylily writes its generated request ID to `x-request-id` for ecosystem compatibility.

`RequestLoggingMiddleware` records method, path, final status, request ID, external correlation ID, duration, and public error reason. `InMemoryRequestLogSink` is available for behavior checks and early tests.

## Route Metadata

Routes can carry runtime metadata without requiring the OpenAPI generator to guess from source code:

```swift
let app = Application {
    Post("/users") {
        Status.created
    }
    .describe(
        summary: "Create user",
        tags: ["Users"],
        inputs: [
            .header("x-daylily", type: "String"),
        ],
        requestBody: .json("CreateUserInput"),
        responses: [
            .response(.created, contentType: "application/json", type: "UserResponse"),
        ]
    )
}

let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
```

`DaylilyOpenAPI` maps route metadata into a minimal OpenAPI document. It converts Daylily path parameters such as `/users/:id` into OpenAPI paths such as `/users/{id}`.

The document is `Codable`, so it can use the existing `JSON(...)` response wrapper:

```swift
let response = JSON(document)
```

This is still an MVP. Deep schema derivation from Swift types is intentionally deferred.

## DaylilyTesting

`DaylilyTesting` provides transport-free test helpers:

```swift
import Daylily
import DaylilyTesting

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}

let response = try await TestClient(app).get("/hello")

try response.requireStatus(.ok)
try response.requireBody("Daylily ships.")
```

It also includes request builders and JSON assertions:

```swift
struct EchoPayload: Codable, Equatable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Equatable, Sendable {
    let echo: String
}

let request = try TestRequest
    .post("/json/echo")
    .withJSON(EchoPayload(message: "hi"))

let jsonResponse = try await TestClient(app).send(request)

try jsonResponse.requireStatus(.ok)
try jsonResponse.requireJSON(EchoResponse(echo: "hi"))
```

`TestClient` calls `Application.respond(to:)` directly, so tests exercise the same in-memory runtime behavior without opening a socket.

## Macro API MVP

Daylily's macro MVP supports this shape:

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

struct CreateUserInput: Codable, Sendable {
    let name: String
}

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(@Path id: Int) -> String {
        "User \(id)"
    }

    @GET("/accounts/:id")
    func account(@Path("id") accountID: Int) -> String {
        "Account \(accountID)"
    }

    @GET("/health")
    func health() -> JSON<HealthPayload> {
        JSON(HealthPayload(status: "ok"))
    }

    @POST("/users")
    func create(@Body input: CreateUserInput) -> Status {
        .created
    }

    @PUT("/users/:id")
    func update(@Path id: Int, req: Request) async throws -> String {
        "updated"
    }

    @PATCH("/users/:id")
    func patch(@Path id: Int, req: Request) async throws -> String {
        "patched"
    }

    @DELETE("/users/:id")
    func delete(@Path id: Int) -> Status {
        .noContent
    }

    @HEAD("/health")
    func head() -> Status {
        .ok
    }

    @OPTIONS("/health")
    func options() -> Status {
        .noContent
    }

    @GET("/search")
    func search(
        @Query term: String,
        @Query("page") pageNumber: Int,
        @Header("x-daylily") token: String
    ) -> String {
        "\(term):\(pageNumber):\(token)"
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

Typed macro inputs also lower into runtime route metadata. `@Path`, `@Query`, `@Header`, and preferred `@Body` inputs contribute OpenAPI-ready metadata through the same `Route.describe(...)` model used by handwritten routes. `@JSONBody` is retained as a compatibility alias spelling for `@Body`.

MVP limits:

- handlers must be instance methods;
- the server type must be default-initializable with `Self()`;
- handlers may use zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, and one `@Body` parameter, with `@JSONBody` accepted as a compatibility alias spelling;
- `@Path` lowers into `req.parameters.require(_:as:)`;
- `@Path` names must match `:name` route segments;
- `@Query` lowers into `req.query.require(_:as:)`;
- `@Header` lowers into `req.headers.require(_:as:)`;
- `@Body` lowers into `try await req.json(Type.self)`; `@JSONBody` is a compatibility alias spelling with the same lowering;
- the raw one-shot request body type is `RequestBody`;
- grouped types must be default-initializable;
- optional typed inputs, macro middleware attributes, DI, and deep OpenAPI schema derivation are future work.

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
├── docs/
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
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

## Architecture Rules

The most important invariants:

- `DaylilyCore` must not depend on NIO.
- User-facing APIs must not expose NIO types.
- Runtime APIs come before macro sugar.
- `swift run` should keep starting the example server.
- `swift test` should keep passing.
- `swift run HelloDaylily --check` should keep passing.
- Public API changes must update AIDEV.

## Roadmap

Near-term:

1. Implement the `Dependencies` registry MVP.
2. Add middleware macro attributes.
3. Expand OpenAPI schema generation.
4. Add WebSocket/realtime experiments.
5. Publish benchmark methodology.

## License

Daylily is released under the [MIT License](LICENSE).

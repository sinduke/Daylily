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
- Declarative route DSL: `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, `Group`.
- Path parameters with `:name` syntax.
- Runtime typed path parameter extraction.
- Runtime typed query and header extraction.
- `Request`, `Response`, `Status`, `Headers`, `Parameters`.
- Daylily-owned `Body` request body model.
- One-shot body consumption with `ByteChunk` and `ByteCount`.
- True NIO request body streaming bridge with bounded buffering and practical backpressure.
- Runtime middleware with application, group, and route scopes.
- `DaylilyObservability` request logging middleware with request ID, correlation ID, latency, status, and public error reason fields.
- Route metadata runtime for OpenAPI generation.
- `DaylilyOpenAPI` minimal OpenAPI document generation from route metadata.
- Application lifecycle hooks: `configure`, `boot`, `started`, `shutdown`, `cleanup`.
- Default SIGINT/SIGTERM graceful server shutdown.
- Explicit `ServerConfiguration` for host, port, backlog, address reuse, read batching, and shutdown signals.
- Explicit `withBufferedBody(upTo:_:)` helper for bounded body inspection and replacement.
- `ResponseConvertible` for `String`, `Status`, and `Response`.
- Async JSON body decoding with `request.body.json(...)` and `request.json(...)`.
- JSON responses with `JSON(...)`.
- NIO-backed HTTP/1.1 server.
- Macro route/group MVP: `@DaylilyServer`, `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`, `@HEAD`, `@OPTIONS`, `@GROUP`.
- Macro `@Path` typed path parameter injection.
- Macro `@Query` and `@Header` typed input injection.
- Macro `@JSONBody` typed JSON body injection.
- Macro typed inputs lower into route metadata for OpenAPI.
- `DaylilyTesting` in-memory `TestClient`, request builders, and JSON assertions.
- Default `swift run` example server.
- Lightweight behavior checks.
- AIDEV project handoff system.

Not implemented yet:

- Macro typed input injection beyond `@Path`, `@Query`, `@Header`, and `@JSONBody` (true `@Body` spelling, optional values, etc.).
- Full OpenAPI schema derivation from Swift types.
- Dependency injection.
- Macro middleware attributes.

## Quick Start

From the project root:

```sh
swift build
swift test
swift run HelloDaylily --check
swift run
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
    func create(@JSONBody input: CreateUserInput) -> Status {
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

Typed macro inputs also lower into runtime route metadata. `@Path`, `@Query`, `@Header`, and `@JSONBody` contribute OpenAPI-ready metadata through the same `Route.describe(...)` model used by handwritten routes.

MVP limits:

- handlers must be instance methods;
- the server type must be default-initializable with `Self()`;
- handlers may use zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, and one `@JSONBody` parameter;
- `@Path` lowers into `req.parameters.require(_:as:)`;
- `@Path` names must match `:name` route segments;
- `@Query` lowers into `req.query.require(_:as:)`;
- `@Header` lowers into `req.headers.require(_:as:)`;
- `@JSONBody` lowers into `try await req.json(Type.self)`;
- true `@Body` spelling is deferred because `Body` is already Daylily's raw request body type;
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

1. Decide and implement true `@Body`.
2. Add beta docs: quickstart, examples, and capability matrix.
3. Add release hygiene: Linux CI, CHANGELOG, semver tag, and public API registry sync.

## License

Daylily is released under the [MIT License](LICENSE).

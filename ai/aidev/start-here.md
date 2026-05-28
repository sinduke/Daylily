# Start Here

This is the first file an AI should read when taking over Daylily.

## What Daylily Is

Daylily is an experimental AI-native web framework for Swift.

Its default surface is macro-driven and declarative:

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

This is a default path, not a mandatory path. Runtime APIs are first-class, macros lower into runtime APIs, and user applications may keep their own composition roots, services, factories, or containers.

Current implemented surfaces are the runtime DSL for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`, runtime route metadata, minimal `DaylilyOpenAPI` document generation, runtime middleware, `DaylilyObservability` request ID and request logging middleware, application lifecycle hooks, app-wide `Dependencies` registry MVP, the Daylily-owned `RequestBody` model, explicit buffered body replacement, JSON body/response helpers, the macro route/group MVP, macro `@Path`, `@Query`, `@Header`, and preferred `@Body` typed JSON input injection with route metadata lowering, `@JSONBody` compatibility alias spelling, and `DaylilyTesting` in-memory request/response helpers.

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
        let id = try request.parameters.require("id", as: Int.self)
        return "User \(id)"
    }
    .describe(
        summary: "Show user",
        tags: ["Users"],
        inputs: [
            .path("id", type: "Int"),
        ],
        responses: [
            .response(.ok, contentType: "text/plain", type: "String"),
        ]
    )

    Get("/search") { request in
        let term = try request.query.require("term", as: String.self)
        let page = try request.query.get("page", as: Int.self) ?? 1
        return "Search \(term) page \(page)"
    }

    Post("/json/echo") { request in
        let input = try await request.json(EchoPayload.self)
        return JSON(EchoResponse(echo: input.message))
    }

    Post("/echo") { request in
        try await request.body.string(upTo: .kilobytes(64))
    }
    .middleware(HeaderMiddleware())

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
.middleware(HeaderMiddleware())
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
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

try await app.run()
```

Middleware order is:

```text
application -> router dispatch -> group -> route -> handler
```

Middleware may read `request.body`, but `RequestBody` is one-shot. There is no hidden body replay. If middleware needs to inspect bytes and pass an equivalent body downstream, use `request.withBufferedBody(upTo:_:)` with an explicit limit.

Observability currently starts as a separate module:

```swift
let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

`RequestIDMiddleware` generates Daylily-owned request IDs. Incoming `x-request-id` is external correlation data, not Daylily's unique request identity. `RequestLoggingMiddleware` records method, path, final status, request ID, external correlation ID, duration, and public error reason. The module depends on `DaylilyCore`, is re-exported by `Daylily`, and must not force logging or tracing dependencies into the core runtime.

Route metadata is runtime-owned:

```swift
let descriptions = app.describeRoutes()
let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
```

`Route.describe(...)` stores summary, description, tags, operation ID, path/query/header inputs, request body metadata, and response metadata. `DaylilyOpenAPI` maps that metadata into a minimal OpenAPI document. Deep schema derivation from Swift types is still deferred.

Macro route/group MVP:

```swift
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

    @POST("/users")
    func create(@Body input: CreateUserInput) -> Status {
        .created
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
}
```

The macro layer lowers into the runtime DSL. Macro limitations are macro limitations, not runtime limitations.

Macro typed inputs also lower into runtime route metadata:

```text
@Path      -> RouteInputMetadata.path(...)
@Query     -> RouteInputMetadata.query(...)
@Header    -> RouteInputMetadata.header(...)
@Body      -> RouteBodyMetadata.json(...)
@JSONBody  -> RouteBodyMetadata.json(...) compatibility alias spelling
```

Testing surface:

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

let jsonRequest = try TestRequest
    .post("/json/echo")
    .withJSON(EchoPayload(message: "hi"))

let jsonResponse = try await TestClient(app).send(jsonRequest)
try jsonResponse.requireJSON(EchoResponse(echo: "hi"))
```

`TestClient` is transport-free and calls `Application.respond(to:)` directly. `TestRequest` builds in-memory `Request` values, and response helpers decode/assert JSON for tests.

Formal tests live in `Tests/DaylilyTests` and use Swift Testing. The test target calls the shared `DaylilyCheckSuite`, so `swift test` and `swift run HelloDaylily --check` exercise the same behavior core.

## Current Stage

Implemented:

- Swift package.
- Core runtime.
- Basic route DSL: `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, `Options`, `Group`.
- Runtime route metadata and `Application.describeRoutes()`.
- Minimal OpenAPI document generation through `Application.openAPI(title:version:)`.
- Runtime middleware at application, group, and route scope.
- `DaylilyObservability` request ID and request logging middleware.
- Application lifecycle hooks: `configure`, `boot`, `started`, `shutdown`, `cleanup`.
- App-wide `Dependencies` registry MVP with concrete `Sendable` `register`, `get`, and `require`.
- Default SIGINT/SIGTERM graceful server shutdown.
- Explicit `ServerConfiguration`.
- Macro route/group MVP: `@DaylilyServer`, `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`, `@HEAD`, `@OPTIONS`, `@GROUP`.
- Macro `@Path` typed path parameter injection.
- Macro `@Query` and `@Header` typed input injection.
- Macro `@Body` typed JSON body injection, with `@JSONBody` kept only as a compatibility alias spelling.
- Macro typed input metadata lowering for OpenAPI.
- Runtime typed path parameter extraction.
- `DaylilyTesting` in-memory `TestClient`, `TestRequest`, and response assertion helpers.
- Daylily-owned `RequestBody` model with one-shot consumption.
- Explicit `request.withBufferedBody(upTo:_:)` helper for bounded body buffering and replacement.
- `ByteChunk`, `BodyBytes`, `ByteCount`, `BodyError`, and `ResponseError`.
- True NIO request body streaming bridge with bounded buffering and practical backpressure.
- Async JSON body decoding with `request.body.json(...)` and `request.json(...)`.
- JSON responses with `JSON(...)`.
- Request and response types.
- Path parameter extraction as strings.
- NIO-backed HTTP server.
- Default `swift run` executable.
- Shared `DaylilyCheckSuite` behavior checks.
- Formal Swift Testing target.
- AIDEV project contract.
- Beta docs in `docs/`, including quickstart, capability matrix, JSON API example, middleware example, and testing example.
- Release hygiene docs, including `CHANGELOG.md` and `docs/release-readiness.md`.
- External SwiftPM consumer smoke script and CI coverage for local path and released package dependency modes.
- Minimal app template in `templates/minimal-app`, plus template smoke validation for path and release dependency modes.
- Commerce API example in `examples/commerce-api`, plus example smoke validation for current checkout path mode.
- Dependency injection design and runtime MVP for the first `Dependencies` registry.

Not implemented:

- Macro typed input injection beyond `@Path`, `@Query`, `@Header`, and `@Body` (optional values, etc.).
- Deep OpenAPI schema derivation.
- Protocol/keyed dependencies, dependency lifecycle integration, and `@Dependency` macro syntax.
- Macro middleware attributes.

## Read Order

Read these before planning or modifying:

1. `AIDEV.md`
2. `ai/aidev/start-here.md`
3. `docs/README.md`
4. `docs/release-readiness.md`
5. `ai/aidev/invariants.md`
6. `ai/aidev/architecture.md`
7. `ai/aidev/runtime-contracts.md`
8. `ai/aidev/api-registry.md`
9. `ai/aidev/extension-playbooks.md`
10. `ai/aidev/task-protocol.md`
11. `ai/aidev/registry.yml`

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
swift test
swift run HelloDaylily --check
scripts/consumer-smoke-test.sh --mode path
scripts/template-smoke-test.sh --mode path
scripts/example-smoke-test.sh --mode path
```

If `swift test` reports `no such module 'Testing'` because the active developer directory is Command Line Tools, run it with the installed Xcode toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
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
- production middleware stack
- benchmarking suite

Current strategic order:

1. Design lifecycle integration in `0020-008`.
2. Add `@Dependency` macro sugar only after keyed runtime and lifecycle contracts are clear.
3. Keep protocol/keyed runtime implementation separate from lifecycle and macro work.

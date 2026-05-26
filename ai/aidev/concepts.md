# Concepts

This file explains Daylily without requiring source code.

## Application

`Application` is the root runtime object.

It owns a `Router` and exposes:

```swift
respond(to:) async -> Response
```

For server usage, the user calls:

```swift
try await app.run()
```

`run()` is added by the user-facing `Daylily` module and uses the NIO transport internally.

## Route

`Route` describes one endpoint:

```text
method + path + handler
```

Examples:

```swift
Get("/hello") { "hello" }
Post("/echo") { request in
    try await request.body.string(upTo: .kilobytes(64))
}
```

Routes are runtime data. Macros generate routes; they do not bypass the route system.

## RouteBuilder

`RouteBuilder` lets users declare multiple routes inside `Application { ... }`.

It supports single routes, `Routes` group collections, conditionals, and arrays of routes.

## Group

`Group` prefixes child routes:

```swift
Group("/api") {
    Get("/health") { "ok" }
}
```

This produces:

```text
GET /api/health
```

Future `@GROUP` should preserve this mental model.

`Group` returns a `Routes` collection so group middleware can be tracked separately from route middleware.

## Middleware

Middleware wraps request handling:

```swift
struct HeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-daylily"] = "ships"
        return response
    }
}
```

Middleware can be attached at application, group, or route scope:

```swift
Application {
    Group("/api") {
        Get("/health") { "ok" }
    }
    .middleware(HeaderMiddleware())

    Get("/hello") { "Daylily ships." }
}
.middleware(HeaderMiddleware())
```

Execution order:

```text
application -> router dispatch -> group -> route -> handler
```

Middleware may short-circuit by returning a response without calling `next`. It may also throw; thrown errors become responses through `Application.respond(to:)`.

Middleware can read `request.body`, but `Body` is one-shot. If middleware consumes the body and calls `next`, downstream code sees the consumed body. Daylily does not do hidden body replay.

## Request

`Request` is the framework-level request model.

Current fields:

```text
method
path
headers
body
parameters
```

`body` is a Daylily-owned `Body`.

Body usage:

```swift
for try await chunk in request.body.bytes {
    chunk.bytes
    chunk.count
}

let bytes = try await request.body.collect(upTo: .megabytes(1))
let text = try await request.body.string(upTo: .kilobytes(64))
```

`Body` is one-shot. Reading bytes, collecting, string decoding, or JSON decoding consumes it. A second read fails with `BodyError.alreadyConsumed`.

When middleware or a handler intentionally needs to inspect body bytes and pass an equivalent body downstream, use explicit buffering:

```swift
try await request.withBufferedBody(upTo: .megabytes(1)) { replayedRequest, bytes in
    try verify(bytes)
    return try await next.respond(to: replayedRequest)
}
```

This consumes the original body, creates a replacement `Body.bytes(...)`, and keeps the replacement body one-shot. There is no hidden body replay.

`DaylilyNIO` now creates a streaming `Body` after receiving the request head. NIO body chunks are fed into `BodyBytes` in order, request end finishes iteration, and channel/protocol errors surface as `BodyError.streamFailed`.

Transport stream creation is hidden behind `@_spi(Transport)`, so user code still reads only `request.body.bytes`, `collect(upTo:)`, `string(upTo:)`, or JSON helpers.

JSON body decoding is provided by `DaylilyJSON`:

```swift
let input = try await request.body.json(CreateUser.self, upTo: .megabytes(1))
let input = try await request.json(CreateUser.self)
```

Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.
The convenience `request.json(...)` uses a default 1 MB body limit.

## Body Helpers

`ByteCount` expresses explicit body limits:

```swift
.bytes(512)
.kilobytes(64)
.megabytes(1)
.gigabytes(1)
```

Unit helpers are 1024-based.

`ByteChunk` is the body stream element. In the first version it exposes:

```swift
chunk.bytes
chunk.count
```

It intentionally does not conform to `Collection` yet.

## Parameters

Path parameters use `:name` syntax:

```swift
Get("/users/:id") { request in
    request.parameters.id
}
```

Untyped parameters are strings:

```swift
request.parameters.id
request.parameters["id"]
```

Runtime typed extraction is available:

```swift
let id = try request.parameters.require("id", as: Int.self)
let optionalPage = try request.parameters.get("page", as: Int.self)
```

First supported types:

- `String`
- `Int`
- `Double`
- `Bool`

Missing or invalid typed path parameters throw `ParameterError` and render as `400 Bad Request`.

Macro `@Path` input injection lowers into the same runtime extraction:

```swift
@GET("/users/:id")
func user(@Path id: Int) -> String {
    "User \(id)"
}

@GET("/accounts/:id")
func account(@Path("id") accountID: Int) -> String {
    "Account \(accountID)"
}
```

`@Path` names must match `:name` route segments. The marker itself does not own extraction behavior.

`UUID` support is deferred because it requires a Foundation decision for `DaylilyCore` or an extension module.

## Handler

`Handler` wraps user closures into a uniform function:

```swift
(Request) async throws -> Response
```

Users can return any `ResponseConvertible`.

## Response

`Response` is the framework-level response model:

```text
status
headers
body
```

Common user returns:

```swift
"hello"
Status.noContent
Response.text("created", status: .created)
JSON(User(id: "42"))
```

`JSON(...)` is an explicit response wrapper. Daylily does not currently make every `Encodable` automatically conform to `ResponseConvertible`.

## ResponseConvertible

`ResponseConvertible` converts user return values into `Response`.

Current conformances:

- `Response`
- `Status`
- `String`
- `JSON<Value>` where `Value: Encodable & Sendable`

Future:

- streaming response
- file response

## ResponseError

`ResponseError` is the runtime error-to-response contract.

Current conformers:

- `Abort`
- `BodyError`

`Application.respond(to:)` maps `ResponseError.status` and `ResponseError.reason` into a text response.

## Router

`Router` matches an incoming `Request` to a `Route`.

Current implementation is simple and may change. Public behavior should remain:

```text
literal > parameter > wildcard
```

## Transport

Transport accepts network traffic and calls:

```swift
(Request) async -> Response
```

Current transport is `DaylilyNIO`.

Transport details must not leak into `DaylilyCore` or user-facing handler APIs.

## Macro Layer

Macro route MVP is implemented.

Current macro-facing attributes:

```swift
@DaylilyServer
@GET("/path")
@POST("/path")
@GROUP("/prefix")
@Path
```

Example:

```swift
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

    @GROUP("/api")
    struct API {
        @GET("/health")
        func health() -> String {
            "ok"
        }
    }
}
```

MVP assumptions:

- server type can be initialized with `Self()`
- grouped types can be initialized with `Self.GroupType()`
- handlers are instance methods
- handlers may have zero parameters, one `Request` parameter, and `@Path` parameters
- `@Path` lowers into `req.parameters.require(_:as:)`

Macros create or expose the same route graph the runtime DSL creates.

The runtime is the source of truth. Macros are a declaration layer on top.

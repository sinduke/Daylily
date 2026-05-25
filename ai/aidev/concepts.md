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
Post("/echo") { request in request.bodyString }
```

Routes are runtime data. Macros generate routes; they do not bypass the route system.

## RouteBuilder

`RouteBuilder` lets users declare multiple routes inside `Application { ... }`.

It supports single routes, groups, conditionals, and arrays of routes.

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

The current body is buffered bytes. This is intentionally temporary.

JSON body decoding is provided by `DaylilyJSON`:

```swift
let input = try request.json(CreateUser.self)
```

Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.

## Parameters

Path parameters use `:name` syntax:

```swift
Get("/users/:id") { request in
    request.parameters.id
}
```

Parameters are strings today. Typed extraction is future work.

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

Current macros:

```swift
@DaylilyServer
@GET("/path")
@POST("/path")
@GROUP("/prefix")
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

MVP assumptions:

- server type can be initialized with `Self()`
- grouped types can be initialized with `Self.GroupType()`
- handlers are instance methods
- handlers have zero parameters or one `Request` parameter

Macros create or expose the same route graph the runtime DSL creates.

The runtime is the source of truth. Macros are a declaration layer on top.

# Conventions

## Naming

Public runtime DSL functions currently use Swift-style capitalized route component names:

```swift
Get("/hello") { ... }
Post("/echo") { ... }
Group("/api") { ... }
```

Future macros use uppercase HTTP method names:

```swift
@GET("/hello")
@POST("/users")
@GROUP("/api")
```

Middleware types use normal Swift type names:

```swift
struct Auth: Middleware { ... }
struct RequestLogger: Middleware { ... }
```

## Handler Shapes

Supported runtime handler forms:

```swift
Get("/hello") {
    "Daylily ships."
}
```

```swift
Get("/users/:id") { request in
    "User \(request.parameters.id ?? "unknown")"
}
```

Handlers may be:

- sync-looking closures inferred as async
- `async`
- `throws`
- `async throws`

Return values must conform to `ResponseConvertible`.

## Path Parameters

Runtime path parameter syntax:

```text
/users/:id
```

Access:

```swift
request.parameters.id
request.parameters["id"]
try request.parameters.require("id", as: Int.self)
try request.parameters.get("page", as: Int.self)
```

Untyped parameter values are `String`.

Typed runtime extraction currently supports:

- `String`
- `Int`
- `Double`
- `Bool`

Missing or invalid typed path parameters map to `400 Bad Request`.

`UUID` is not supported in `DaylilyCore` yet because Foundation support needs a separate design decision.

Macro `@Path` injection:

```swift
@GET("/users/:id")
func user(@Path id: Int) async throws -> User

@GET("/accounts/:id")
func account(@Path("id") accountID: Int) async throws -> Account
```

Rules:

- `@Path` lowers to `req.parameters.require(_:as:)`.
- Bare `@Path` uses the Swift local parameter name.
- `@Path("name")` maps to an explicit route parameter name.
- `@Path` names must match `:name` segments in the full route path.
- `UUID` remains deferred until the Foundation boundary is decided.

## Request Body

Current:

```swift
request.body
try await request.body.collect(upTo: .megabytes(1))
try await request.body.string(upTo: .kilobytes(64))
try await request.body.json(UserInput.self, upTo: .megabytes(1))
try await request.json(UserInput.self)
try await request.withBufferedBody(upTo: .megabytes(1)) { replayed, bytes in ... }
```

`request.body` is a one-shot `Body`. Reading bytes, collecting, decoding string, or decoding JSON consumes it.

Collection helpers must use explicit limits. `request.json(Type.self)` is convenience sugar with a default 1 MB limit.

Macro JSON body injection:

```swift
@POST("/users")
func create(@JSONBody input: CreateUserInput) async throws -> Status
```

Rules:

- `@JSONBody` lowers to `try await req.json(CreateUserInput.self)`.
- The marker lives in `DaylilyJSON`.
- It uses the existing default `request.json(...)` limit of 1 MB.
- True `@Body` spelling is deferred because `Body` is already Daylily's raw request body type.

`ByteCount.kilobytes`, `.megabytes`, and `.gigabytes` are 1024-based.

```swift
for try await chunk in request.body.bytes { ... }
```

`DaylilyNIO` creates streaming bodies through `@_spi(Transport)` hooks. Keep those hooks transport-only and keep user-facing APIs free of NIO types.

Middleware may read `request.body`, but reading consumes the same one-shot body seen by downstream handlers. Do not add hidden body replay.

Use `withBufferedBody(upTo:_:)` only when the caller explicitly wants in-memory buffering and replacement. The replacement body is still one-shot, and `upTo:` is required.

Macro future:

```swift
func upload(@RawBody body: Body) async throws -> UploadResult
```

## Responses

Prefer small, direct response conversion:

```swift
"hello"
Status.noContent
Response.text("hello", status: .created)
JSON(UserOutput(...), status: .created)
```

JSON response support is explicit. Use `JSON(...)`; do not make every `Encodable` automatically conform to `ResponseConvertible` without a separate design task.

## Errors

Use:

```swift
throw Abort(.notFound)
throw Abort(.badRequest, reason: "Invalid input")
```

Runtime-owned errors that can render HTTP responses should conform to `ResponseError`.

Current `BodyError` mapping:

- body too large: `413 Payload Too Large`
- already consumed: `500 Internal Server Error`
- stream failed: `400 Bad Request`
- invalid UTF-8: `400 Bad Request`

Do not leak raw internal error descriptions in default production responses.

## Sendability

Public closures should be `@Sendable`.

Public runtime types should conform to `Sendable` when practical.

Transport internals may use `@unchecked Sendable` only when constrained by NIO event-loop semantics and documented locally.

## Dependencies

`DaylilyCore` should remain extremely small.

Allowed:

- Swift Standard Library

Allowed outside core:

- Foundation in `DaylilyJSON`
- NIO in `DaylilyNIO`

Avoid in `DaylilyCore` unless justified:

- Foundation
- NIO
- logging packages
- JSON packages

Transport-specific dependencies belong outside core.

## Documentation Updates

When adding public API:

1. Update `ai/aidev/api-registry.md`.
2. Update `ai/aidev/registry.yml`.
3. Update README if it changes user-facing usage.
4. Add or update an epic in `ai/epics/` when the theme is new.
5. Add or update a task in `ai/tasks/`.
6. Keep sub-work as task-local steps; do not create `A/B/C` task files for steps.

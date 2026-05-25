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
```

Current parameter values are `String`.

Future typed extraction:

```swift
@GET("/users/:id")
func user(@Path id: UUID) async throws -> User
```

## Request Body

Current:

```swift
request.body
request.bodyString
try request.json(UserInput.self)
```

Current body is fully buffered in memory. Do not claim large upload support yet.

Future:

```swift
for try await chunk in request.body.bytes { ... }
```

Macro future:

```swift
func upload(@Body(.stream) body: BodyStream) async throws -> UploadResult
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
4. Add or update a task in `ai/tasks/`.

# 0009 Middleware System

Status: implemented

Purpose:

- Add a runtime middleware pipeline before macro sugar.
- Define global, group, and route middleware scoping.
- Define ordering, short-circuiting, error behavior, and body interaction rules.
- Keep middleware consistent with Daylily's one-shot `Body` model.

Tasks:

- `ai/tasks/0009-001-middleware-runtime.md`
- `ai/tasks/0009-002-explicit-buffered-body-helper.md`

Design Direction:

- Runtime first, macros later.
- Public middleware should be protocol-shaped so named middleware types are easy to document, reuse, and test.
- Internal storage may use type erasure if Swift requires it.
- Middleware should receive a `Request` and a `next` handler.
- Middleware may return a response without calling `next`.
- Middleware errors should flow through the existing `Application.respond(to:)` error mapping.

Target shape:

```swift
public protocol Middleware: Sendable {
    func handle(_ request: Request, next: Handler) async throws -> Response
}
```

Target ordering:

```text
Application middleware
-> Router dispatch
   -> Group middleware
   -> Route middleware
   -> Handler
```

For matched routes, this is observed as:

```text
Application middleware
-> Group middleware
-> Route middleware
-> Handler
```

Application middleware should wrap every request, including missing routes. Group and route middleware only run after a route match, with path parameters populated. Response flow naturally unwinds in reverse order.

Target runtime API examples:

```swift
let app = Application {
    Group("/api") {
        Get("/health") {
            "ok"
        }
    }
    .middleware(Auth())

    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(Logger())
```

```swift
Get("/profile") { request in
    "profile"
}
.middleware(Auth())
```

Body Policy:

- Middleware can read `request.body`.
- `request.body` remains one-shot.
- If middleware consumes the body and then calls `next`, downstream code sees the body as already consumed.
- 0009-001 does not add automatic body replay.
- A middleware that wants downstream code to read an equivalent body must explicitly create and pass a request with a replacement `Body`.
- 0009-002 adds an explicit `withBufferedBody` helper for this case.
- Body consumption failures keep the existing `BodyError` mappings, including clear `413 Payload Too Large` behavior.

Non-goals for the first task:

- `@Use`, `@Middleware`, or route macro middleware attributes.
- Middleware body replay helpers.
- Request context or dependency injection.
- Production middleware stack.
- Response body streaming.

Follow-up Target:

```swift
try await request.withBufferedBody(upTo: .megabytes(1)) { replayedRequest, bytes in
    try verify(bytes)
    return try await next.respond(to: replayedRequest)
}
```

0009-002 rules:

- The helper name is `withBufferedBody`.
- The helper starts in `DaylilyCore`.
- The replacement body remains one-shot.
- The helper requires `upTo: ByteCount`.
- The helper buffers in memory only.
- The helper is explicit; Daylily still does not perform automatic body replay.

Notes:

- 0009 follows the 0008 body work because middleware/body interaction must be explicit.
- 0009-001 proved the runtime pipeline before exposing additional syntax.
- 0009-002 added an explicit buffered body helper without changing one-shot body semantics.
- Future tasks can add macro middleware attributes, request context, and production middleware packages.

# 0009 Middleware System

Status: implemented

Purpose:

- Add a runtime middleware pipeline before macro sugar.
- Define global, group, and route middleware scoping.
- Define ordering, short-circuiting, error behavior, and body interaction rules.
- Keep middleware consistent with Daylily's one-shot `Body` model.

Tasks:

- `ai/tasks/0009-001-middleware-runtime.md`

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
- A middleware that wants downstream code to read an equivalent body must explicitly create and pass a request with a replacement `Body`; a dedicated replay helper can be a future task.
- Body consumption failures keep the existing `BodyError` mappings, including clear `413 Payload Too Large` behavior.

Non-goals for the first task:

- `@Use`, `@Middleware`, or route macro middleware attributes.
- Middleware body replay helpers.
- Request context or dependency injection.
- Production middleware stack.
- Response body streaming.

Notes:

- 0009 follows the 0008 body work because middleware/body interaction must be explicit.
- 0009-001 proved the runtime pipeline before exposing additional syntax.
- Future tasks can add macro middleware attributes, explicit body replay helpers, request context, and production middleware packages.

# 0009-001 Middleware Runtime

Status: implemented
Epic: 0009-middleware-system

Goal:

- Add Daylily's first runtime middleware pipeline.
- Support application, group, and route middleware scopes.
- Define middleware ordering, short-circuiting, error behavior, and body interaction clearly enough for AI agents to implement and extend safely.

Scope:

- Add a public middleware protocol.
- Add whatever internal type erasure or pipeline adapter is needed.
- Allow middleware to be attached globally to `Application`.
- Allow middleware to be attached to groups.
- Allow middleware to be attached to individual routes.
- Compose middleware in deterministic order.
- Preserve the existing handler return model and `ResponseConvertible` behavior.
- Add checks for ordering, short-circuiting, thrown errors, and body consumption behavior.
- Update AIDEV documentation after implementation.

Non-goals:

- Macro middleware syntax such as `@Use` or `@Middleware`.
- Automatic body replay.
- Request context storage.
- Dependency injection.
- Production auth/session/CORS/logger implementations.
- Response body streaming.
- New transport behavior.

Steps:

- [x] 0009-001.1 Define the public middleware protocol and internal storage shape.
- [x] 0009-001.2 Add route-level middleware storage and `.middleware(...)` sugar.
- [x] 0009-001.3 Add group middleware propagation to child routes.
- [x] 0009-001.4 Add application-level middleware.
- [x] 0009-001.5 Compose pipeline order as application -> router dispatch -> group -> route -> handler.
- [x] 0009-001.6 Add checks for order, short-circuiting, thrown errors, and route matching.
- [x] 0009-001.7 Add checks documenting body consumption from middleware.
- [x] 0009-001.8 Update AIDEV docs, README examples if needed, and registry.
- [x] 0009-001.9 Review, fix, validate, then finish the task.

Architecture impact:

- Middleware belongs in `DaylilyCore`.
- `DaylilyCore` must remain transport-free and must not import NIO.
- Macro syntax remains a layer above runtime and is not part of this task.
- Existing NIO transport should continue to call `Application.respond(to:)`.
- Application middleware should wrap every request, including missing routes.
- Group and route middleware should run only after route matching has populated path parameters.

Public API impact:

Expected first shape:

```swift
public protocol Middleware: Sendable {
    func handle(_ request: Request, next: Handler) async throws -> Response
}
```

Expected usage:

```swift
struct Auth: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        guard request.headers["authorization"] != nil else {
            return Response.text(
                "Unauthorized",
                status: Status(401, reasonPhrase: "Unauthorized")
            )
        }

        return try await next.respond(to: request)
    }
}
```

```swift
let app = Application {
    Group("/api") {
        Get("/health") {
            "ok"
        }
    }
    .middleware(Auth())
}
```

Implementation decision:

- `Route` can directly store middleware.
- `Group` returns a `Routes` collection wrapper so group middleware can preserve chained and nested ordering.
- `Application.middleware(...)` can return a copy with global middleware, preserving value semantics.

Middleware order:

```text
Application middleware
-> Router dispatch
   -> Group middleware
   -> Route middleware
   -> Handler
```

For matched routes, the effective order is:

```text
Application middleware
-> Group middleware
-> Route middleware
-> Handler
```

For missing routes, application middleware still runs and the router produces the existing `404 Not Found` response.

If multiple middleware exist at the same scope, preserve declaration order:

```text
.middleware(A()).middleware(B())
```

should execute:

```text
A before
B before
handler
B after
A after
```

Short-circuit behavior:

- Middleware may return a `Response` without calling `next`.
- Downstream middleware and handler must not run after a short-circuit.
- Already-executed upstream middleware may still observe or transform the returned response if its implementation awaited `next`.

Error behavior:

- Middleware may throw.
- Thrown `ResponseError` values should map through the existing `Application.respond(to:)` behavior.
- Unknown thrown errors should map to `500 Internal Server Error`.
- Middleware should not need a separate error renderer in this task.

Body behavior:

- Middleware can read `request.body`.
- Reading `request.body` consumes it.
- Calling `next` after consuming the body forwards the same one-shot body state.
- If downstream code reads the already-consumed body, it should receive the existing `BodyError.alreadyConsumed` behavior.
- 0009-001 must not add automatic replay, hidden buffering, or implicit cloning.
- A future task may add an explicit helper for buffering and replacing a consumed body when a middleware intentionally wants replay behavior.

AIDEV updates required:

- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/architecture.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `README.md`
- `README.zh-CN.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Suggested checks:

- Global middleware wraps route handler.
- Global middleware wraps missing-route responses.
- Group middleware wraps only grouped routes.
- Route middleware wraps only that route.
- Ordering is application -> router dispatch -> group -> route -> handler.
- Nested group middleware resolves outer -> inner -> route.
- Short-circuit skips downstream middleware and handler.
- Throwing middleware maps through existing error handling.
- Middleware can inspect headers and path parameters.
- Middleware can consume body, and downstream body reads are still one-shot.

Completed validation:

- `swift build`
- `swift run HelloDaylily --check`
- `registry.yml` YAML parse check
- `git diff --check`
- Server smoke:
  - `GET /hello` returned `200 OK`
  - `GET /users/42` returned `200 OK`
  - `POST /echo` returned `200 OK`
  - `GET /missing` returned `404 Not Found`

Notes:

- This task intentionally keeps middleware boring at the runtime level. The fancy part can come later as macro sugar.
- The body policy mirrors Daylily's existing 0008 contract: convenience is allowed, but hidden buffering is not the default.

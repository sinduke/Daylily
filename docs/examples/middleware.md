# Middleware Example

Daylily middleware is available at application, group, and route scope.

## Add a Response Header

```swift
import Daylily

struct PoweredByMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-powered-by"] = "daylily"
        return response
    }
}

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(PoweredByMiddleware())
```

## Use Middleware at Group and Route Scope

```swift
let app = Application {
    Group("/api") {
        Get("/health") {
            "ok"
        }
    }
    .middleware(PoweredByMiddleware())

    Post("/echo") { request in
        try await request.body.string(upTo: .kilobytes(64))
    }
    .middleware(PoweredByMiddleware())
}
```

Middleware order is:

```text
application -> router dispatch -> group -> route -> handler
```

## Body Inspection Rule

`RequestBody` is one-shot. If middleware reads `request.body` and then calls `next`, downstream code sees an already-consumed body.

When middleware intentionally needs to inspect the bytes and pass an equivalent body downstream, use explicit buffering:

```swift
struct SignatureMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await request.withBufferedBody(upTo: .megabytes(1)) { replayed, bytes in
            try verifySignature(bytes)
            return try await next.respond(to: replayed)
        }
    }
}
```

The replacement body is still one-shot. Daylily does not perform hidden body replay.

## Observability Middleware

`DaylilyObservability` is re-exported by `Daylily`:

```swift
let app = Application {
    Get("/hello") { request in
        request.daylilyRequestID ?? "missing"
    }
}
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

`RequestIDMiddleware` generates a Daylily-owned `x-daylily-request-id`. Incoming `x-request-id` is treated as external correlation data.

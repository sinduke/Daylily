# Architecture

## Layering

Daylily is divided into four runtime-facing conceptual layers plus separate testing support:

```text
User API
  ↓
Runtime Core
  ↓
Transport Adapter
  ↓
Network Runtime
```

Current concrete mapping:

```text
Daylily
  ↓
DaylilyMacros
  ↓
SwiftSyntax

Daylily
  ↓
DaylilyCore

Daylily
  ↓
DaylilyJSON
  ↓
DaylilyCore

DaylilyJSON
  ↓
Foundation

DaylilyTesting
  ↓
DaylilyCore

DaylilyTesting
  ↓
Foundation

DaylilyCheckSuite
  ↓
Daylily / DaylilyTesting

DaylilyTests
  ↓
DaylilyCheckSuite / Swift Testing

Daylily
  ↓
DaylilyNIO
  ↓
SwiftNIO

Daylily
  ↓
DaylilyObservability
  ↓
DaylilyCore

Daylily
  ↓
DaylilyOpenAPI
  ↓
DaylilyCore
```

This diagram is conceptual. Package dependencies are:

```text
Daylily -> DaylilyCore
Daylily -> DaylilyJSON
Daylily -> DaylilyMacros
Daylily -> DaylilyNIO
Daylily -> DaylilyObservability
Daylily -> DaylilyOpenAPI
DaylilyJSON -> DaylilyCore
DaylilyJSON -> Foundation
DaylilyObservability -> DaylilyCore
DaylilyOpenAPI -> DaylilyCore
DaylilyTesting -> DaylilyCore
DaylilyTesting -> Foundation
DaylilyCheckSuite -> Daylily
DaylilyCheckSuite -> DaylilyCore
DaylilyCheckSuite -> DaylilyTesting
DaylilyTests -> Daylily
DaylilyTests -> DaylilyCheckSuite
DaylilyTests -> DaylilyTesting
DaylilyTests -> Swift Testing
DaylilyMacros -> SwiftSyntax
DaylilyNIO -> DaylilyCore
DaylilyNIO -> SwiftNIO
DaylilyCore -> Standard Library only
```

Middleware lives in `DaylilyCore`. It is runtime infrastructure, not transport infrastructure.

Lifecycle phases live in `DaylilyCore`. `Application.run` wires them to the current transport, and `DaylilyNIO` only exposes a transport-level `started` callback for bind completion.

## Non-Negotiable Boundaries

`DaylilyCore` must not import:

- `NIOCore`
- `NIOHTTP1`
- `NIOPosix`
- Foundation unless a specific need is documented

Public user APIs must not expose:

- `EventLoopFuture`
- `Channel`
- `ChannelHandler`
- `ChannelHandlerContext`
- `ByteBuffer`

The transport may use those internally.

JSON support lives in `DaylilyJSON`, not `DaylilyCore`. `DaylilyJSON` may import Foundation for `JSONEncoder`, `JSONDecoder`, and `Data`.

Testing support lives in `DaylilyTesting`, not `DaylilyCore`. `DaylilyTesting` may use Foundation for test JSON helpers, must stay transport-free and NIO-free, and should call `Application.respond(to:)` directly.

Behavior checks live in `DaylilyCheckSuite` and are exercised by both `swift test` and `swift run HelloDaylily --check`. The formal test target uses Swift Testing and must not open a network port for in-memory behavior checks.

Observability helpers live in `DaylilyObservability`, not `DaylilyCore`. The first slice is request logging middleware. It may depend on `DaylilyCore`, but it must not force logging backends, tracing SDKs, metrics clients, or transport-specific APIs into the core runtime.

OpenAPI document generation lives in `DaylilyOpenAPI`, not `DaylilyCore`. `DaylilyCore` stores runtime metadata; `DaylilyOpenAPI` converts route descriptions into OpenAPI DTOs. Deep Swift schema derivation is not part of the first generator slice.

## Runtime First

New features should first be expressible through runtime APIs.

Example:

```swift
Application {
    Get("/hello") {
        "Daylily ships."
    }

    Put("/users/:id") { request in
        "updated"
    }

    Delete("/users/:id") {
        Status.noContent
    }
}
```

Runtime route verbs currently include `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, and `Options`. `HEAD` and `OPTIONS` are explicit route methods; there is no automatic `HEAD -> GET` fallback or automatic `OPTIONS Allow` response yet.

Macro syntax lowers into runtime APIs.

Implemented MVP:

```swift
@GET("/hello")
func hello() -> String {
    "Daylily ships."
}
```

Should become equivalent to:

```swift
Get("/hello") {
    try await instance.hello()
}
```

## Request Path

Current HTTP request flow:

```text
NIO Channel
  ↓
HTTPServerRequestPart.head/body/end
  ↓
DaylilyNIO creates Request on head and streams body chunks
  ↓
DaylilyCore.Request with streaming RequestBody
  ↓
Application middleware
  ↓
Router
  ↓
Group middleware
  ↓
Route middleware
  ↓
Handler
  ↓
ResponseConvertible
  ↓
String / Status / Response / JSON<Value>
  ↓
DaylilyCore.Response
  ↓
NIO HTTP response parts
```

Current body handling uses the Daylily `RequestBody` abstraction. In-process requests may still use `RequestBody.bytes(...)`, while `DaylilyNIO` creates a streaming `RequestBody` as soon as it receives the request head.

0008-001 body model:

```text
Request.body -> RequestBody
RequestBody.bytes -> BodyBytes
BodyBytes.Element -> ByteChunk
collect/string/json helpers require limits
```

`RequestBody` is one-shot and backed by shared storage, so copying `RequestBody` does not allow a second read.

0008-002 NIO streaming bridge:

```text
NIO head -> Request(body: streaming RequestBody) -> route handler starts
NIO body chunk -> BodyStreamWriter -> BodyBytes -> ByteChunk
NIO end -> finish BodyBytes
NIO error/close -> BodyError.streamFailed
```

`DaylilyCore` owns the stream model and exposes transport hooks through `@_spi(Transport)`. Public user APIs still do not expose NIO types.

0009-001 middleware runtime:

```text
Application middleware -> router dispatch -> group middleware -> route middleware -> handler
```

Application middleware wraps every request, including missing routes. Group and route middleware run only after a route match, so path parameters are available. Middleware may read `request.body`, but the `RequestBody` remains one-shot and Daylily does not replay it automatically.

0013-001 request logging middleware:

```text
RequestLoggingMiddleware
  ↓
next.respond(to:)
  ↓
RequestLog(method, path, final status)
  ↓
RequestLogSink
```

Request logging is a normal middleware and follows the same ordering, short-circuiting, and error mapping rules as other middleware. It records the final response status for successful downstream responses, `ResponseError.status` for framework errors, and `500 Internal Server Error` for unknown thrown errors.

0013-002 request ID and timing:

```text
RequestIDMiddleware
  ↓
generate dl_<UUID> requestID
  ↓
read external x-request-id as correlationID
  ↓
write x-daylily-request-id and compatibility x-request-id
  ↓
RequestLoggingMiddleware records IDs, status, duration, and public error reason
```

Daylily never relies on externally supplied IDs for uniqueness. `x-daylily-request-id` is the Daylily-generated request identity. Incoming `x-request-id` is treated as external correlation data and is preserved when present.

0014-001 route metadata runtime:

```text
Route.describe(...)
  ↓
RouteMetadata
  ↓
Application.describeRoutes()
  ↓
[RouteDescription]
```

OpenAPI metadata starts in the runtime route model. Macros and generators must lower into or read this runtime metadata instead of inventing a parallel source of truth. Route metadata is descriptive only; it does not change matching, middleware order, lifecycle behavior, or handler execution.

0014-002 minimal OpenAPI document:

```text
Application.describeRoutes()
  ↓
DaylilyOpenAPI.OpenAPIBuilder
  ↓
OpenAPIDocument
```

The generator maps Daylily route paths such as `/users/:id` into OpenAPI paths such as `/users/{id}`. It maps known scalar Swift type names into simple OpenAPI schema types and preserves unknown Swift type names through `x-swift-type`.

0014-003 macro metadata bridge:

```text
@Path / @Query / @Header / @Body
@JSONBody compatibility alias spelling for @Body
  ↓
@DaylilyServer generated Get/Post route
  ↓
Route.describe(inputs:requestBody:)
  ↓
DaylilyOpenAPI
```

The macro layer does not own a separate metadata model. It lowers handler input annotations into the same runtime metadata used by handwritten routes.

## Router Rules

Current router is simple array-based matching with scoring.

Priority:

```text
literal > parameter > wildcard
```

This preserves expected behavior:

```text
/users/me      beats /users/:id
/users/42      matches /users/:id
```

Future router may become trie/radix based without changing public API.

## Error Rules

Runtime errors should become responses through `Application.respond(to:)`.

Current behavior:

- `ResponseError` maps to its status and reason.
- `Abort` conforms to `ResponseError`.
- `BodyError` conforms to `ResponseError`.
- Unknown errors map to `500 Internal Server Error`.
- Missing route maps to `404 Not Found`.
- Request body over limit maps to `413 Payload Too Large`.
- Application middleware can transform error responses produced by router dispatch.

Future:

- Add configurable error renderer.
- Hide internal errors in production.
- Provide debug metadata in development.

## Macro Architecture

Implemented target:

```text
DaylilyMacros
```

Implemented macro flow:

```text
@DaylilyServer
  scans route declarations
  generates static main() async throws
  creates Self()
  builds Application { ... }
  calls app.run()

@GET / @POST / @PUT / @PATCH / @DELETE / @HEAD / @OPTIONS
  marker macros
  used by @DaylilyServer

@GROUP
  marker macro on nested structs
  contributes a path prefix
  used by @DaylilyServer

@Path
  parameter marker
  used by @DaylilyServer
  lowers into Parameters.require(_:as:)

@Query
  parameter marker
  used by @DaylilyServer
  lowers into QueryParameters.require(_:as:)

@Header
  parameter marker
  used by @DaylilyServer
  lowers into Headers.require(_:as:)

@Body
@JSONBody compatibility alias spelling for @Body
  parameter marker
  used by @DaylilyServer
  lowers into Request.json(_:upTo:) through request.json(Type.self)
```

Typed macro inputs lower twice:

- into runtime extraction calls used by handlers
- into `Route.describe(...)` metadata used by OpenAPI

MVP limits:

- server type must be default-initializable with `Self()`
- group types must be default-initializable
- route handlers must be instance methods
- route handlers may have zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, and one `@Body` parameter; `@JSONBody` remains as a compatibility alias spelling
- `@Path` names must match `:name` route segments
- raw one-shot request body values use `RequestBody`
- optional typed inputs, DI, macro middleware attributes, and deep OpenAPI schema derivation are not part of this MVP

Important rule:

The macro layer must not become the only way to build routes. Runtime APIs remain the ground truth.

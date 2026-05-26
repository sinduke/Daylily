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

Daylily
  ↓
DaylilyNIO
  ↓
SwiftNIO
```

This diagram is conceptual. Package dependencies are:

```text
Daylily -> DaylilyCore
Daylily -> DaylilyJSON
Daylily -> DaylilyMacros
Daylily -> DaylilyNIO
DaylilyJSON -> DaylilyCore
DaylilyJSON -> Foundation
DaylilyTesting -> DaylilyCore
DaylilyTesting -> Foundation
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

## Runtime First

New features should first be expressible through runtime APIs.

Example:

```swift
Application {
    Get("/hello") {
        "Daylily ships."
    }
}
```

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
DaylilyCore.Request with streaming Body
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

Current body handling uses the Daylily `Body` abstraction. In-process requests may still use `Body.bytes(...)`, while `DaylilyNIO` creates a streaming `Body` as soon as it receives the request head.

0008-001 body model:

```text
Request.body -> Body
Body.bytes -> BodyBytes
BodyBytes.Element -> ByteChunk
collect/string/json helpers require limits
```

`Body` is one-shot and backed by shared storage, so copying `Body` does not allow a second read.

0008-002 NIO streaming bridge:

```text
NIO head -> Request(body: streaming Body) -> route handler starts
NIO body chunk -> BodyStreamWriter -> BodyBytes -> ByteChunk
NIO end -> finish BodyBytes
NIO error/close -> BodyError.streamFailed
```

`DaylilyCore` owns the stream model and exposes transport hooks through `@_spi(Transport)`. Public user APIs still do not expose NIO types.

0009-001 middleware runtime:

```text
Application middleware -> router dispatch -> group middleware -> route middleware -> handler
```

Application middleware wraps every request, including missing routes. Group and route middleware run only after a route match, so path parameters are available. Middleware may read `request.body`, but the `Body` remains one-shot and Daylily does not replay it automatically.

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
- Body over limit maps to `413 Payload Too Large`.
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

@GET / @POST
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

@JSONBody
  parameter marker
  used by @DaylilyServer
  lowers into Request.json(_:upTo:) through request.json(Type.self)
```

MVP limits:

- server type must be default-initializable with `Self()`
- group types must be default-initializable
- route handlers must be instance methods
- route handlers may have zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, and one `@JSONBody` parameter
- `@Path` names must match `:name` route segments
- true `@Body` spelling is deferred because `Body` is already Daylily's raw request body type
- optional typed inputs, DI, macro middleware attributes, and OpenAPI are not part of this MVP

Important rule:

The macro layer must not become the only way to build routes. Runtime APIs remain the ground truth.

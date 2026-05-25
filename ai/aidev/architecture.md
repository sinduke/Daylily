# Architecture

## Layering

Daylily is divided into four conceptual layers:

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
DaylilyMacros -> SwiftSyntax
DaylilyNIO -> DaylilyCore
DaylilyNIO -> SwiftNIO
DaylilyCore -> Standard Library only
```

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
DaylilyNIO accumulates body bytes for 0008A
  ↓
DaylilyCore.Request with Body.bytes(...)
  ↓
Router
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

Current body handling is buffered. Streaming body is a planned runtime capability and must be designed before large upload support.

0008A body model:

```text
Request.body -> Body
Body.bytes -> BodyBytes
BodyBytes.Element -> ByteChunk
collect/string/json helpers require limits
```

`Body` is one-shot and backed by shared storage, so copying `Body` does not allow a second read. True transport-level chunk streaming and backpressure remain planned for 0008B.

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
```

MVP limits:

- server type must be default-initializable with `Self()`
- group types must be default-initializable
- route handlers must be instance methods
- route handlers may have zero parameters or one `Request` parameter
- `@Path`, `@Body`, DI, middleware, and OpenAPI are not part of this MVP

Important rule:

The macro layer must not become the only way to build routes. Runtime APIs remain the ground truth.

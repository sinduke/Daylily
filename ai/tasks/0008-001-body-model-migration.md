# 0008-001 Body Model Migration

Status: implemented
Epic: 0008-body-system

Steps:

- [x] 0008-001.1 Migrate public body model.

## Goal

Replace the current buffered request body surface with a Daylily-owned `Body` model while keeping the NIO transport allowed to buffer internally for this phase.

This task defines the public/runtime body API. It does not claim true transport-level streaming yet.

## Scope

- Replace `Request.body: [UInt8]` with `Request.body: Body`.
- Add `Body` as the single public request body abstraction.
- Make `Body` uniformly one-shot.
- Keep `Body` as a public value type backed by shared storage so copies cannot bypass consumption state.
- Add `BodyBytes: AsyncSequence` with `ByteChunk` elements.
- Add `ByteChunk` with only `bytes` and `count` in the first version.
- Add `ByteCount` helpers for bytes, kilobytes, megabytes, and gigabytes.
- Add explicit collection helpers:
  - `collect(upTo:)`
  - `string(upTo:)`
- Add `BodyError`.
- Add `ResponseError`.
- Make `Abort` and `BodyError` conform to `ResponseError`.
- Add `Status.payloadTooLarge`.
- Migrate JSON decoding to async body APIs in `DaylilyJSON`.
- Keep `request.json(...)` as convenience sugar over `request.body.json(...)`.
- Update examples, checks, README, and AIDEV docs.

## Non-goals

- True NIO request streaming.
- Transport backpressure.
- Response body streaming.
- Multipart parsing.
- File upload helpers.
- `@Body` macro injection.
- Middleware body replay.
- HTTP/2.
- TLS.

## Architecture Impact

`DaylilyCore`:

- Owns `Body`, `BodyBytes`, `ByteChunk`, `ByteCount`, `BodyError`, and `ResponseError`.
- Still must not import NIO.
- Still must not expose `ByteBuffer`, `EventLoopFuture`, `Channel`, or `ChannelHandlerContext`.

`DaylilyJSON`:

- Owns JSON decoding extensions.
- Moves JSON body decoding onto async body collection.
- Keeps Foundation JSON APIs out of `DaylilyCore`.

`DaylilyNIO`:

- For 0008-001, could continue buffering the full body.
- For 0008-001, had to create `Request.body` as `Body.bytes(...)`.
- 0008-002 later replaced this transport buffering with true chunk feeding.

`HelloDaylily`:

- Updates `/echo` and `/json/echo` to async body APIs.
- Adds behavior checks for body one-shot, limits, JSON, UTF-8, and 413 behavior.

## Public API Impact

Target request shape:

```swift
public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: Body
    public let parameters: Parameters
}
```

Compatibility initializer may still accept buffered bytes:

```swift
public init(
    method: HTTPMethod,
    path: String,
    headers: Headers = [:],
    body: [UInt8] = [],
    parameters: Parameters = Parameters()
)
```

Body:

```swift
public struct Body: Sendable {
    public var bytes: BodyBytes { get }

    public static func bytes(_ bytes: [UInt8]) -> Body

    public func collect(upTo limit: ByteCount) async throws -> [UInt8]
    public func string(upTo limit: ByteCount) async throws -> String
}
```

Body bytes:

```swift
public struct BodyBytes: AsyncSequence, Sendable {
    public typealias Element = ByteChunk
}
```

Byte chunk:

```swift
public struct ByteChunk: Sendable {
    public var bytes: [UInt8] { get }
    public var count: Int { get }
}
```

Do not make `ByteChunk` conform to `Collection` in the first version.

Byte count:

```swift
public struct ByteCount: Equatable, Comparable, Sendable {
    public let bytes: Int

    public static func bytes(_ value: Int) -> ByteCount
    public static func kilobytes(_ value: Int) -> ByteCount
    public static func megabytes(_ value: Int) -> ByteCount
    public static func gigabytes(_ value: Int) -> ByteCount
}
```

`kilobytes`, `megabytes`, and `gigabytes` are 1024-based:

```text
1 KB = 1024 bytes
1 MB = 1024 KB
1 GB = 1024 MB
```

Response error:

```swift
public protocol ResponseError: Error, Sendable {
    var status: Status { get }
    var reason: String { get }
}
```

Body error:

```swift
public enum BodyError: ResponseError {
    case alreadyConsumed
    case tooLarge(limit: ByteCount)
    case streamFailed
    case invalidEncoding
}
```

Error mapping:

```text
BodyError.tooLarge        -> 413 Payload Too Large, "Request body too large"
BodyError.alreadyConsumed -> 500 Internal Server Error, "Request body already consumed"
BodyError.streamFailed    -> 400 Bad Request, "Request body stream failed"
BodyError.invalidEncoding -> 400 Bad Request, "Invalid UTF-8 body"
```

JSON standard API:

```swift
let input = try await request.body.json(CreateUser.self, upTo: .megabytes(1))
```

JSON convenience API:

```swift
let input = try await request.json(CreateUser.self)
```

Convenience behavior:

```text
request.json(Type.self) == request.body.json(Type.self, upTo: .megabytes(1))
```

Default JSON body limit:

```text
1 MB
```

## One-Shot Rules

`Body` is uniformly one-shot.

These operations consume the body:

- iterating `request.body.bytes`
- `collect(upTo:)`
- `string(upTo:)`
- `request.body.json(...)`
- `request.json(...)`

A second consumption attempt throws:

```swift
BodyError.alreadyConsumed
```

This applies even when `Body` is copied:

```swift
let a = request.body
let b = request.body

try await a.collect(upTo: .megabytes(1))
try await b.collect(upTo: .megabytes(1)) // BodyError.alreadyConsumed
```

## Implementation Notes

`Body` should be a public struct with private shared storage:

```swift
public struct Body: Sendable {
    private let storage: BodyStorage
}
```

0008-001 may implement buffered `Body` first:

```text
Body.bytes([UInt8]) -> BodyBytes yields one ByteChunk
```

Do not split buffered bodies into multiple chunks unless there is a concrete reason in this phase.

## Validation

Required:

```sh
swift build
swift run HelloDaylily --check
```

Completed:

- `swift build`
- `swift run HelloDaylily --check`
- server smoke with `/hello`, `/echo`, `/json/health`, and `/json/echo`

Checks to add:

- `Body.bytes(...)` yields a `ByteChunk`.
- `ByteChunk.bytes` preserves the original bytes.
- `ByteChunk.count` matches byte count.
- `collect(upTo:)` returns bytes under limit.
- `collect(upTo:)` throws `BodyError.tooLarge` above limit.
- Over-limit route returns `413 Payload Too Large`.
- `string(upTo:)` decodes valid UTF-8.
- Invalid UTF-8 returns `400 Bad Request` with `Invalid UTF-8 body`.
- Body is one-shot.
- Copied body is still one-shot through shared storage.
- JSON standard API succeeds.
- JSON convenience API succeeds with default 1 MB limit.
- Invalid JSON still returns `400 Bad Request` with `Invalid JSON body`.

## AIDEV Updates Required

- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
- `ai/aidev/concepts.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/conventions.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `README.md`
- `README.zh-CN.md`

## Notes

- 0008-001 is the API and runtime body model migration.
- 0008-001 intentionally does not claim true transport-level streaming.
- 0008-002 implemented the NIO true streaming bridge and backpressure work.

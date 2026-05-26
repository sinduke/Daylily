# API Registry

This file tracks the current public API surface. Update it whenever public names, signatures, or parameter semantics change.

## Module Daylily

### Re-exports

```swift
@_exported import DaylilyCore
@_exported import DaylilyJSON
@_exported import DaylilyNIO
```

### Macros

```swift
@attached(member, names: named(main))
public macro DaylilyServer()

@attached(peer)
public macro GET(_ path: String)

@attached(peer)
public macro POST(_ path: String)

@attached(peer)
public macro GROUP(_ prefix: String)
```

Rules:

- `@DaylilyServer` generates `static func main() async throws`.
- The generated main creates `let server = Self()`.
- Route handlers must be instance methods.
- Route handlers may have zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, and one `@JSONBody` parameter.
- `@GET` lowers to runtime `Get`.
- `@POST` lowers to runtime `Post`.
- `@GROUP` marks a nested struct as a route group and contributes a path prefix.
- `@Path` lowers into `req.parameters.require(_:as:)`.
- Bare `@Path` uses the Swift local parameter name.
- `@Path("name")` maps to an explicit path parameter name.
- `@Path` names must match `:name` segments in the full route path.
- `@Query` lowers into `req.query.require(_:as:)`.
- Bare `@Query` uses the Swift local parameter name.
- `@Query("name")` maps to an explicit query parameter name.
- `@Header` lowers into `req.headers.require(_:as:)`.
- Bare `@Header` uses the Swift local parameter name.
- `@Header("name")` maps to an explicit header name.
- `@JSONBody` lowers into `try await req.json(Type.self)`.
- True `@Body` spelling is deferred because `Body` is already Daylily's raw request body type.
- Grouped types are instantiated with `Self.GroupType()`.

### Application.run

```swift
extension Application {
    public func run(host: String = "127.0.0.1", port: Int = 8080) async throws
}
```

Parameters:

- `host`: address to bind. Default `127.0.0.1`.
- `port`: port to bind. Default `8080`.

Lifecycle order:

```text
configure -> boot -> NIO bind -> started -> server close -> shutdown -> cleanup
```

## Module DaylilyTesting

### TestClient

```swift
public struct TestClient: Sendable {
    public init(_ application: Application)

    public func respond(to request: Request) async throws -> Response

    public func send(_ request: TestRequest) async throws -> Response

    public func get(
        _ path: String,
        headers: Headers = [:]
    ) async throws -> Response

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: Body = .bytes([])
    ) async throws -> Response

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: [UInt8]
    ) async throws -> Response

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: String
    ) async throws -> Response

    public func postJSON<Value: Encodable>(
        _ path: String,
        headers: Headers = [:],
        body value: Value
    ) async throws -> Response
}
```

### TestRequest

```swift
public struct TestRequest: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var headers: Headers
    public var body: Body

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: Body = .bytes([])
    )

    public static func get(_ path: String, headers: Headers = [:]) -> TestRequest
    public static func post(_ path: String, headers: Headers = [:], body: Body = .bytes([])) -> TestRequest

    public func withHeader(_ name: String, _ value: String) -> TestRequest
    public func withBody(_ body: Body) -> TestRequest
    public func withBody(_ bytes: [UInt8]) -> TestRequest
    public func withBody(_ string: String) -> TestRequest
    public func withJSON<Value: Encodable>(_ value: Value) throws -> TestRequest
    public func toRequest() -> Request
}
```

### Response Testing Helpers

```swift
public enum TestFailure: Error, Sendable, CustomStringConvertible {
    case status(expected: Status, actual: Status)
    case body(expected: String, actual: String)
    case json(reason: String)
}

public extension Response {
    func json<Value: Decodable>(_ type: Value.Type = Value.self) throws -> Value
    func requireStatus(_ expected: Status) throws
    func requireBody(_ expected: String) throws
    func requireJSON<Value: Decodable & Equatable>(
        _ expected: Value,
        as type: Value.Type = Value.self
    ) throws
}
```

Rules:

- `TestClient` is transport-free.
- `TestClient` calls `Application.respond(to:)` directly.
- `TestClient` depends on `DaylilyCore`, not NIO.
- `TestRequest` is a builder for in-memory Daylily `Request` values.
- `TestRequest.withJSON(...)` sets `content-type: application/json` when absent.
- Response testing helpers live in `DaylilyTesting`, not `DaylilyCore`.
- Runtime JSON request/response behavior remains owned by `DaylilyJSON`.

## Module DaylilyCore

### Application

```swift
public struct Application: Sendable {
    public init(@RouteBuilder routes: () -> [Route])
    public init(routes: [Route])
    public init(routes: Routes)
    public func middleware<M: Middleware>(_ middleware: M) -> Application
    public func lifecycle(_ phase: LifecyclePhase, _ operation: @escaping LifecycleOperation) -> Application
    public func configure(_ operation: @escaping LifecycleOperation) -> Application
    public func boot(_ operation: @escaping LifecycleOperation) -> Application
    public func started(_ operation: @escaping LifecycleOperation) -> Application
    public func shutdown(_ operation: @escaping LifecycleOperation) -> Application
    public func cleanup(_ operation: @escaping LifecycleOperation) -> Application
    public func runLifecycle(_ phase: LifecyclePhase) async throws
    public func respond(to request: Request) async -> Response
}
```

Rules:

- `respond(to:)` catches framework errors and always returns a `Response`.
- It is the in-memory test surface for runtime behavior.
- Application middleware wraps every request, including missing routes and error responses produced by router dispatch.
- Lifecycle hooks are async, throwing, and run in registration order within each phase.
- `respond(to:)` does not run lifecycle hooks.

### Lifecycle

```swift
public typealias LifecycleOperation = @Sendable () async throws -> Void

public enum LifecyclePhase: String, Sendable, CaseIterable {
    case configure
    case boot
    case started
    case shutdown
    case cleanup
}
```

Rules:

- `configure` and `boot` run before server bind in `Application.run`.
- `started` runs after NIO bind succeeds.
- `shutdown` and `cleanup` run after server close.
- `shutdown` and `cleanup` are attempted if server run fails after boot.
- Lifecycle APIs do not expose NIO types.

### Route

```swift
public struct Route: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let handler: Handler

    public init(method: HTTPMethod, path: String, handler: Handler)

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> R
    )

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable () async throws -> R
    )

    public func prefixed(with prefix: String) -> Route
    public func middleware<M: Middleware>(_ middleware: M) -> Route
}
```

Path rules:

- Stored paths are normalized to begin with `/`.
- Empty path becomes `/`.
- Group prefixes are joined without duplicate slashes.
- Route middleware runs after application and group middleware.
- Route middleware preserves declaration order.

### Route DSL

```swift
public func Get<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route

public func Get<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route

public func Post<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route

public func Post<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route

public func Group(_ prefix: String, @RouteBuilder routes: () -> [Route]) -> Routes
```

Current verbs:

- `Get`
- `Post`

### Routes

```swift
public struct Routes: Sendable {
    public func middleware<M: Middleware>(_ middleware: M) -> Routes
}
```

Rules:

- `Routes` is the current group route collection wrapper.
- `RouteBuilder` accepts `Routes` expressions.
- Group middleware is resolved before route middleware.
- Chained group middleware preserves declaration order.

### Middleware

```swift
public protocol Middleware: Sendable {
    func handle(_ request: Request, next: Handler) async throws -> Response
}
```

Rules:

- Middleware lives in `DaylilyCore`.
- Application middleware runs before router dispatch and wraps missing-route responses.
- Group and route middleware run after route matching, so path parameters are available.
- Middleware may short-circuit by returning a response without calling `next`.
- Middleware may throw; errors map through `Application.respond(to:)`.
- Middleware may read `request.body`, but `Body` remains one-shot.
- Daylily does not automatically replay consumed request bodies.

Planned verbs:

- `Put`
- `Patch`
- `Delete`

### Request

```swift
public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: Body
    public let parameters: Parameters
    public let query: QueryParameters

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: Body = .bytes([]),
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil
    )

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8],
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil
    )

    public func with(parameters: Parameters) -> Request
    public func with(body: Body) -> Request

    public func withBufferedBody<R: Sendable>(
        upTo limit: ByteCount,
        _ operation: @Sendable (Request, [UInt8]) async throws -> R
    ) async throws -> R
}
```

Rules:

- Initializers strip query text from `path` and populate `query` when `path` includes `?`.
- Explicit `query:` overrides query text parsed from `path`.
- `with(parameters:)`, `with(body:)`, and `withBufferedBody(upTo:_:)` preserve query values.

Body rules:

- `body` is a Daylily-owned `Body`.
- The `[UInt8]` initializer converts bytes into `Body.bytes(...)`.
- `with(parameters:)` preserves the same `Body` storage and one-shot state.
- `with(body:)` replaces only the body and preserves method, path, headers, and parameters.
- `withBufferedBody(upTo:_:)` consumes the current body, creates a replacement `Body.bytes(...)`, and passes both replacement request and collected bytes to the closure.
- `withBufferedBody(upTo:_:)` requires an explicit `ByteCount` limit.
- The replacement body from `withBufferedBody(upTo:_:)` is still one-shot.
- Limit failures from `withBufferedBody(upTo:_:)` throw `BodyError.tooLarge`.
- `DaylilyNIO` creates streaming bodies through transport SPI; user code still sees only `Body`.

### Body

```swift
public struct Body: Sendable {
    public static func bytes(_ bytes: [UInt8]) -> Body
    public var bytes: BodyBytes { get }
    public func collect(upTo limit: ByteCount) async throws -> [UInt8]
    public func string(upTo limit: ByteCount) async throws -> String
}
```

Rules:

- `Body` is one-shot.
- Reading `bytes`, `collect(upTo:)`, `string(upTo:)`, or JSON consumes the body.
- A second read throws `BodyError.alreadyConsumed`.
- `Body` is a public value type backed by shared storage.
- Copying `Body` does not reset one-shot state.
- Transport-owned streaming construction exists behind `@_spi(Transport)` and is not normal user API.

### BodyBytes

```swift
public struct BodyBytes: AsyncSequence, Sendable {
    public typealias Element = ByteChunk
    public func makeAsyncIterator() -> AsyncIterator
}
```

Rules:

- Buffered bodies yield at most one `ByteChunk`.
- Streaming transport bodies yield `ByteChunk` values in receive order.
- Stream finish ends async iteration cleanly.
- Stream failure throws `BodyError.streamFailed`.

### Body Transport SPI

```swift
@_spi(Transport)
public static func Body.stream(bufferLimit: ByteCount = .megabytes(1)) -> BodyStream

@_spi(Transport)
public struct BodyStream: Sendable {
    public let body: Body
    public let writer: BodyStreamWriter
}

@_spi(Transport)
public struct BodyStreamWriter: Sendable {
    public func write(_ chunk: ByteChunk) async -> Bool
    public func finish() async
    public func fail() async
    public func cancel() async
}
```

Rules:

- This SPI is for transports such as `DaylilyNIO`.
- Normal user code should not call it.
- `write(_:)` awaits bounded-buffer capacity and returns `false` if the stream is already terminal.
- `finish()` ends iteration, `fail()` maps readers to `BodyError.streamFailed`, and `cancel()` unblocks readers without surfacing a transport error.
- `DaylilyCore` still does not import NIO.

### ByteChunk

```swift
public struct ByteChunk: Sendable {
    public let bytes: [UInt8]
    public init(_ bytes: [UInt8])
    public var count: Int { get }
}
```

Rules:

- First version exposes only `bytes` and `count`.
- It does not conform to `Collection`.

### ByteCount

```swift
public struct ByteCount: Comparable, Sendable {
    public let bytes: Int

    public init(bytes: Int)
    public static func bytes(_ value: Int) -> ByteCount
    public static func kilobytes(_ value: Int) -> ByteCount
    public static func megabytes(_ value: Int) -> ByteCount
    public static func gigabytes(_ value: Int) -> ByteCount
}
```

Rules:

- Values must be non-negative.
- Unit helpers are 1024-based.

### BodyError

```swift
public enum BodyError: ResponseError {
    case alreadyConsumed
    case tooLarge(limit: ByteCount)
    case streamFailed
    case invalidEncoding
}
```

Mappings:

- `.alreadyConsumed`: `500 Internal Server Error`, `Request body already consumed`
- `.tooLarge`: `413 Payload Too Large`, `Request body too large`
- `.streamFailed`: `400 Bad Request`, `Request body stream failed`
- `.invalidEncoding`: `400 Bad Request`, `Invalid UTF-8 body`

### Response

```swift
public struct Response: Sendable {
    public var status: Status
    public var headers: Headers
    public var body: [UInt8]

    public init(status: Status = .ok, headers: Headers = [:], body: [UInt8] = [])

    public static func text(
        _ value: String,
        status: Status = .ok,
        headers: Headers = [:]
    ) -> Response

    public var bodyString: String { get }
}
```

### ResponseConvertible

```swift
public protocol ResponseConvertible: Sendable {
    func toResponse() async throws -> Response
}
```

Current conformances:

- `Response`
- `Status`
- `String`
- `JSON<Value>` where `Value: Encodable & Sendable`

Planned conformances:

- Byte/stream response wrapper

### Handler

```swift
public struct Handler: Sendable {
    public init(_ closure: @escaping @Sendable (Request) async throws -> Response)
    public func respond(to request: Request) async throws -> Response
}
```

### Router

```swift
public struct Router: Sendable {
    public init(routes: [Route] = [])
    public func respond(to request: Request) async throws -> Response
}
```

Router is public for now, but should be treated as runtime infrastructure.

### HTTPMethod

```swift
public enum HTTPMethod: String, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"

    public init?(_ rawValue: String)
}
```

### Status

```swift
public struct Status: Equatable, Sendable {
    public let code: Int
    public let reasonPhrase: String

    public init(_ code: Int, reasonPhrase: String)
}
```

Current constants:

- `.ok`
- `.created`
- `.noContent`
- `.badRequest`
- `.payloadTooLarge`
- `.notFound`
- `.internalServerError`

### Headers

```swift
public struct Headers: Equatable, Sendable, ExpressibleByDictionaryLiteral {
    public init(_ values: [String: String] = [:])
    public init(dictionaryLiteral elements: (String, String)...)
    public subscript(_ name: String) -> String? { get set }
    public var all: [(name: String, value: String)] { get }
    public func require<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value
    public func get<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value?
}
```

Rules:

- Header names are stored lowercased.
- Multiple values for the same header are not supported yet.
- `require(_:as:)` throws `HeaderError.missing` when the header is absent.
- `require(_:as:)` and `get(_:as:)` throw `HeaderError.invalid` when conversion fails.

### QueryParameters

```swift
@dynamicMemberLookup
public struct QueryParameters: Equatable, Sendable {
    public init(_ storage: [String: String] = [:])
    public subscript(_ name: String) -> String? { get }
    public subscript(dynamicMember name: String) -> String? { get }
    public func require<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value
    public func get<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value?
}
```

Rules:

- Query parsing supports `&` pairs, `name=value`, empty values, `+` as space, and percent-decoded UTF-8 bytes.
- Repeated query names currently use last value wins.
- `require(_:as:)` throws `QueryParameterError.missing` when the query value is absent.
- `require(_:as:)` and `get(_:as:)` throw `QueryParameterError.invalid` when conversion fails.

### Parameters

```swift
@dynamicMemberLookup
public struct Parameters: Equatable, Sendable {
    public init(_ storage: [String: String] = [:])
    public subscript(_ name: String) -> String? { get }
    public subscript(dynamicMember name: String) -> String? { get }
    public func require<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value
    public func get<Value: ParameterDecodable>(_ name: String, as type: Value.Type = Value.self) throws -> Value?
}
```

Usage:

```swift
request.parameters["id"]
request.parameters.id
let id = try request.parameters.require("id", as: Int.self)
let maybePage = try request.parameters.get("page", as: Int.self)
```

Rules:

- Untyped lookup remains optional `String`.
- `require(_:as:)` throws `ParameterError.missing` when the key is absent.
- `require(_:as:)` and `get(_:as:)` throw `ParameterError.invalid` when conversion fails.
- First built-in conformers: `String`, `Int`, `Double`, `Bool`.
- `UUID` is not supported in `DaylilyCore` yet.

### ParameterDecodable

```swift
public protocol ParameterDecodable: Sendable {
    static var parameterTypeDescription: String { get }
    static func decodeParameter(_ value: String) -> Self?
}
```

Current conformers:

- `String`
- `Int`
- `Double`
- `Bool`

### ParameterError

```swift
public enum ParameterError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)
}
```

Mappings:

- `.missing`: `400 Bad Request`, `Missing path parameter: <name>`
- `.invalid`: `400 Bad Request`, `Invalid path parameter <name>: expected <type>`

### QueryParameterError

```swift
public enum QueryParameterError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)
}
```

Mappings:

- `.missing`: `400 Bad Request`, `Missing query parameter: <name>`
- `.invalid`: `400 Bad Request`, `Invalid query parameter <name>: expected <type>`

### HeaderError

```swift
public enum HeaderError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)
}
```

Mappings:

- `.missing`: `400 Bad Request`, `Missing header: <name>`
- `.invalid`: `400 Bad Request`, `Invalid header <name>: expected <type>`

### Path

```swift
@propertyWrapper
public struct Path<Value: ParameterDecodable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value)
    public init(wrappedValue: Value, _ name: String)
}
```

Rules:

- `Path` is a parameter marker used by `@DaylilyServer`.
- It is public so users can write `func user(@Path id: Int)`.
- It does not perform extraction by itself.
- Macro lowering calls `Parameters.require(_:as:)`.
- Supported value types are the current `ParameterDecodable` conformers.
- `UUID` is not supported yet.

### Query

```swift
@propertyWrapper
public struct Query<Value: ParameterDecodable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value)
    public init(wrappedValue: Value, _ name: String)
}
```

Rules:

- `Query` is a parameter marker used by `@DaylilyServer`.
- Macro lowering calls `QueryParameters.require(_:as:)`.

### Header

```swift
@propertyWrapper
public struct Header<Value: ParameterDecodable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value)
    public init(wrappedValue: Value, _ name: String)
}
```

Rules:

- `Header` is a parameter marker used by `@DaylilyServer`.
- Macro lowering calls `Headers.require(_:as:)`.

### ResponseError

```swift
public protocol ResponseError: Error, Sendable {
    var status: Status { get }
    var reason: String { get }
}
```

Current conformers:

- `Abort`
- `BodyError`
- `ParameterError`

`Application.respond(to:)` converts `ResponseError` values into text responses using `status` and `reason`.

### Abort

```swift
public struct Abort: Error, Sendable {
    public let status: Status
    public let reason: String

    public init(_ status: Status, reason: String? = nil)
}
```

## Module DaylilyJSON

### JSON Response Wrapper

```swift
public struct JSON<Value: Encodable & Sendable>: ResponseConvertible {
    public var value: Value
    public var status: Status
    public var headers: Headers

    public init(
        _ value: Value,
        status: Status = .ok,
        headers: Headers = [:]
    )

    public func toResponse() async throws -> Response
}
```

Rules:

- Encodes with Foundation `JSONEncoder`.
- Sets `content-type: application/json` if no content type is already present.
- Does not make all `Encodable` types automatically conform to `ResponseConvertible`.

### Body JSON Decoding

```swift
public extension Body {
    func json<Value: Decodable>(_ type: Value.Type, upTo limit: ByteCount) async throws -> Value
}

public extension Request {
    func json<Value: Decodable>(
        _ type: Value.Type,
        upTo limit: ByteCount = .megabytes(1)
    ) async throws -> Value
}
```

Rules:

- `request.body.json(Type.self, upTo:)` is the standard JSON body API.
- `request.json(Type.self)` is convenience sugar with a default 1 MB limit.
- Decodes collected body bytes with Foundation `JSONDecoder`.
- Body collection limit failures keep their `BodyError` mapping.
- Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.
- Request content type is not enforced yet.

### JSONBody

```swift
@propertyWrapper
public struct JSONBody<Value: Decodable & Sendable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value)
}
```

Rules:

- `JSONBody` is a macro marker for typed JSON body injection.
- It lives in `DaylilyJSON`, not `DaylilyCore`.
- `@DaylilyServer` lowers it into `try await req.json(Type.self)`.
- The marker does not own runtime decode behavior.

## Module DaylilyNIO

### NIOServerConfiguration

```swift
public struct NIOServerConfiguration: Sendable {
    public var host: String
    public var port: Int

    public init(host: String = "127.0.0.1", port: Int = 8080)
}
```

### NIOHTTPServer

```swift
public struct NIOHTTPServer: Sendable {
    public init(
        configuration: NIOServerConfiguration = NIOServerConfiguration(),
        responder: @escaping @Sendable (Request) async -> Response
    )

    public func run(started: @escaping @Sendable () async throws -> Void = {}) async throws
}
```

Rules:

- This is transport infrastructure.
- Most users should call `Application.run(...)` instead.
- Creates `Request` after NIO request head with a streaming `Body`.
- Feeds NIO request body chunks into `BodyBytes`.
- Uses bounded buffering and NIO `autoRead` control for practical backpressure.
- Does not expose `ByteBuffer`, `HTTPServerRequestPart`, `Channel`, or `ChannelHandlerContext` through user APIs.

## Module DaylilyMacros

This is a macro implementation target, not a user-facing runtime module.

Public macro implementation types:

```swift
public struct DaylilyServerMacro
public struct RouteMarkerMacro
```

Rules:

- Macro implementations generate code that uses `Application`, `Get`, and `Post`.
- `@GROUP` changes generated route paths, not `DaylilyCore`.
- Macro implementations must not replace the runtime route system.

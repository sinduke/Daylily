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
- Route handlers may have zero parameters or one `Request` parameter.
- `@GET` lowers to runtime `Get`.
- `@POST` lowers to runtime `Post`.
- `@GROUP` marks a nested struct as a route group and contributes a path prefix.
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

## Module DaylilyCore

### Application

```swift
public struct Application: Sendable {
    public init(@RouteBuilder routes: () -> [Route])
    public init(routes: [Route])
    public func respond(to request: Request) async -> Response
}
```

Rules:

- `respond(to:)` catches framework errors and always returns a `Response`.
- It is the in-memory test surface for runtime behavior.

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
}
```

Path rules:

- Stored paths are normalized to begin with `/`.
- Empty path becomes `/`.
- Group prefixes are joined without duplicate slashes.

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

public func Group(_ prefix: String, @RouteBuilder routes: () -> [Route]) -> [Route]
```

Current verbs:

- `Get`
- `Post`

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
    public let body: [UInt8]
    public let parameters: Parameters

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8] = [],
        parameters: Parameters = Parameters()
    )

    public var bodyString: String { get }
    public func with(parameters: Parameters) -> Request
}
```

Body rules:

- Current body model is buffered bytes.
- Large body and upload support should use a future streaming abstraction.

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
- `.notFound`
- `.internalServerError`

### Headers

```swift
public struct Headers: Equatable, Sendable, ExpressibleByDictionaryLiteral {
    public init(_ values: [String: String] = [:])
    public init(dictionaryLiteral elements: (String, String)...)
    public subscript(_ name: String) -> String? { get set }
    public var all: [(name: String, value: String)] { get }
}
```

Rules:

- Header names are stored lowercased.
- Multiple values for the same header are not supported yet.

### Parameters

```swift
@dynamicMemberLookup
public struct Parameters: Equatable, Sendable {
    public init(_ storage: [String: String] = [:])
    public subscript(_ name: String) -> String? { get }
    public subscript(dynamicMember name: String) -> String? { get }
}
```

Usage:

```swift
request.parameters["id"]
request.parameters.id
```

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

### Request JSON Decoding

```swift
public extension Request {
    func json<Value: Decodable>(_ type: Value.Type) throws -> Value
}
```

Rules:

- Decodes the current buffered `Request.body` with Foundation `JSONDecoder`.
- Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.
- Request content type is not enforced yet.

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

    public func run() async throws
}
```

Rules:

- This is transport infrastructure.
- Most users should call `Application.run(...)` instead.

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

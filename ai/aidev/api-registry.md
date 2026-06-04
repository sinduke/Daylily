# API Registry

This file tracks the current public API surface. Update it whenever public names, signatures, or parameter semantics change.

## Module Daylily

### Default Path Principle

Daylily APIs provide recommended defaults, not mandatory application architecture. Runtime APIs are first-class. Macros must lower into runtime APIs and must not become the only way to express a supported app shape.

### Re-exports

```swift
@_exported import DaylilyCore
@_exported import DaylilyJSON
@_exported import DaylilyNIO
@_exported import DaylilyObservability
@_exported import DaylilyOpenAPI
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
public macro PUT(_ path: String)

@attached(peer)
public macro PATCH(_ path: String)

@attached(peer)
public macro DELETE(_ path: String)

@attached(peer)
public macro HEAD(_ path: String)

@attached(peer)
public macro OPTIONS(_ path: String)

@attached(peer)
public macro GROUP(_ prefix: String)
```

Rules:

- `@DaylilyServer` generates `static func main() async throws`.
- The generated main creates `let server = Self()`.
- If the server type defines `func configureDependencies(_ dependencies: inout Dependencies)`, the generated main calls it and passes the result to `Application(routes:dependencies:)`.
- The generated main accepts an optional `--port <number>` command-line argument and otherwise listens on port `8080`.
- Route handlers must be instance methods.
- Route handlers may have zero parameters, one `Request` parameter, `@Path`, `@Query`, `@Header`, `@Dependency`, and one `@Body` parameter, with `@JSONBody` accepted as a compatibility alias spelling.
- `@GET` lowers to runtime `Get`.
- `@POST` lowers to runtime `Post`.
- `@PUT` lowers to runtime `Put`.
- `@PATCH` lowers to runtime `Patch`.
- `@DELETE` lowers to runtime `Delete`.
- `@HEAD` lowers to runtime `Head`.
- `@OPTIONS` lowers to runtime `Options`.
- `@GROUP` marks a nested struct as a route group and contributes a path prefix.
- `@Path` lowers into `req.parameters.require(_:as:)`.
- `@Path` also lowers into `RouteInputMetadata.path(...)`.
- Bare `@Path` uses the Swift local parameter name.
- `@Path("name")` maps to an explicit path parameter name.
- `@Path` names must match `:name` segments in the full route path.
- `@Query` lowers into `req.query.require(_:as:)`.
- `@Query` also lowers into `RouteInputMetadata.query(...)`.
- Bare `@Query` uses the Swift local parameter name.
- `@Query("name")` maps to an explicit query parameter name.
- `@Header` lowers into `req.headers.require(_:as:)`.
- `@Header` also lowers into `RouteInputMetadata.header(...)`.
- Bare `@Header` uses the Swift local parameter name.
- `@Header("name")` maps to an explicit header name.
- `@Body` lowers into `try await req.json(Type.self)`.
- `@Body` also lowers into `RouteBodyMetadata.json(...)`.
- `@JSONBody` is a compatibility alias spelling for `@Body` and uses the same lowering.
- `@Dependency(key)` lowers into `try req.dependencies.require(key)`.
- `@Dependency` requires exactly one `DependencyKey<Value>` expression and does not infer dependencies from parameter type alone.
- `@Dependency` does not contribute route metadata.
- The raw one-shot request body type is `RequestBody`.
- Grouped types are instantiated with `Self.GroupType()`.
- These are macro rules, not runtime rules. Runtime route DSL remains a first-class supported API when macro limits do not fit an application.

### Application.run

```swift
extension Application {
    public func run(host: String = "127.0.0.1", port: Int = 8080) async throws
    public func run(configuration: ServerConfiguration) async throws
}
```

Parameters:

- `host`: address to bind. Default `127.0.0.1`.
- `port`: port to bind. Default `8080`.
- `configuration`: explicit server configuration.

Lifecycle order:

```text
configure -> boot -> NIO bind -> started -> server close -> shutdown -> cleanup
```

## Module DaylilyObservability

### RequestLog

```swift
public struct RequestLog: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var status: Status
    public var requestID: String?
    public var correlationID: String?
    public var durationNanoseconds: UInt64?
    public var errorReason: String?

    public init(
        method: HTTPMethod,
        path: String,
        status: Status,
        requestID: String? = nil,
        correlationID: String? = nil,
        durationNanoseconds: UInt64? = nil,
        errorReason: String? = nil
    )
}
```

### RequestLogSink

```swift
public protocol RequestLogSink: Sendable {
    func record(_ log: RequestLog) async
}
```

### RequestLoggingMiddleware

```swift
public struct RequestLoggingMiddleware<Sink: RequestLogSink>: Middleware {
    public init(sink: Sink)
    public func handle(_ request: Request, next: Handler) async throws -> Response
}
```

### Request ID

```swift
public typealias RequestIDGenerator = @Sendable () -> String

public enum RequestIDHeaders {
    public static let requestID: String
    public static let daylilyRequestID: String
}

public enum RequestIDs {
    public static func generate() -> String
}

public struct RequestIDMiddleware: Middleware {
    public init(generator: @escaping RequestIDGenerator = RequestIDs.generate)
    public func handle(_ request: Request, next: Handler) async throws -> Response
}

public extension Request {
    var daylilyRequestID: String? { get }
    var correlationID: String? { get }
    func withRequestIDs(requestID: String, correlationID: String?) -> Request
}
```

### Sinks

```swift
public struct ConsoleRequestLogSink: RequestLogSink {
    public init()
    public func record(_ log: RequestLog) async
}

public actor InMemoryRequestLogSink: RequestLogSink {
    public init()
    public func record(_ log: RequestLog)
    public func snapshot() -> [RequestLog]
}
```

Rules:

- `DaylilyObservability` depends on `DaylilyCore` and uses Foundation for default UUID request ID generation.
- `RequestIDMiddleware` generates `x-daylily-request-id`.
- Incoming `x-request-id` is external correlation data, not Daylily's unique request identity.
- `RequestLoggingMiddleware` records method, path, final status, request ID, external correlation ID, duration, and public error reason.
- Successful downstream responses record `response.status`.
- Thrown `ResponseError` values record `error.status` and then rethrow.
- Unknown thrown errors record `500 Internal Server Error` and then rethrow.
- The module must not require a logging backend, tracing SDK, or transport dependency.

## Module DaylilyOpenAPI

### OpenAPI Document API

```swift
public struct OpenAPIDocument: Codable, Equatable, Sendable
public struct OpenAPIInfo: Codable, Equatable, Sendable
public struct OpenAPIOperation: Codable, Equatable, Sendable
public struct OpenAPIParameter: Codable, Equatable, Sendable
public struct OpenAPIRequestBody: Codable, Equatable, Sendable
public struct OpenAPIResponse: Codable, Equatable, Sendable
public struct OpenAPIMediaType: Codable, Equatable, Sendable
public struct OpenAPISchema: Codable, Equatable, Sendable

public struct OpenAPIBuilder: Sendable {
    public init()

    public func document(
        for routes: [RouteDescription],
        title: String,
        version: String,
        openapi: String = "3.1.0"
    ) -> OpenAPIDocument
}

public extension Application {
    func openAPI(title: String, version: String, openapi: String = "3.1.0") -> OpenAPIDocument
}
```

Rules:

- `DaylilyOpenAPI` depends on `DaylilyCore`.
- `Application.openAPI(title:version:)` reads `Application.describeRoutes()`.
- Daylily route paths such as `/users/:id` map to OpenAPI paths such as `/users/{id}`.
- Path/query/header metadata maps to OpenAPI parameters.
- JSON body metadata maps to OpenAPI request body content.
- Response metadata maps to OpenAPI responses.
- Unknown Swift type names map to object schemas with `x-swift-type`.
- Deep schema derivation is deferred.

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
        body: RequestBody = .bytes([])
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

    public func put(_ path: String, headers: Headers = [:], body: RequestBody = .bytes([])) async throws -> Response
    public func put(_ path: String, headers: Headers = [:], body: [UInt8]) async throws -> Response
    public func put(_ path: String, headers: Headers = [:], body: String) async throws -> Response

    public func patch(_ path: String, headers: Headers = [:], body: RequestBody = .bytes([])) async throws -> Response
    public func patch(_ path: String, headers: Headers = [:], body: [UInt8]) async throws -> Response
    public func patch(_ path: String, headers: Headers = [:], body: String) async throws -> Response

    public func delete(_ path: String, headers: Headers = [:]) async throws -> Response
    public func head(_ path: String, headers: Headers = [:]) async throws -> Response
    public func options(_ path: String, headers: Headers = [:]) async throws -> Response
}
```

### TestRequest

```swift
public struct TestRequest: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var headers: Headers
    public var body: RequestBody

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([])
    )

    public static func get(_ path: String, headers: Headers = [:]) -> TestRequest
    public static func post(_ path: String, headers: Headers = [:], body: RequestBody = .bytes([])) -> TestRequest
    public static func put(_ path: String, headers: Headers = [:], body: RequestBody = .bytes([])) -> TestRequest
    public static func patch(_ path: String, headers: Headers = [:], body: RequestBody = .bytes([])) -> TestRequest
    public static func delete(_ path: String, headers: Headers = [:]) -> TestRequest
    public static func head(_ path: String, headers: Headers = [:]) -> TestRequest
    public static func options(_ path: String, headers: Headers = [:]) -> TestRequest

    public func withHeader(_ name: String, _ value: String) -> TestRequest
    public func withBody(_ body: RequestBody) -> TestRequest
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
    public init(
        dependencies configureDependencies: @Sendable (inout Dependencies) -> Void = { _ in },
        @RouteBuilder routes: () -> [Route]
    )
    public init(routes: [Route])
    public init(routes: [Route], dependencies: Dependencies)
    public init(routes: Routes)
    public func middleware<M: Middleware>(_ middleware: M) -> Application
    public func lifecycle(_ phase: LifecyclePhase, _ operation: @escaping LifecycleOperation) -> Application
    public func configure(_ operation: @escaping LifecycleOperation) -> Application
    public func boot(_ operation: @escaping LifecycleOperation) -> Application
    public func started(_ operation: @escaping LifecycleOperation) -> Application
    public func shutdown(_ operation: @escaping LifecycleOperation) -> Application
    public func cleanup(_ operation: @escaping LifecycleOperation) -> Application
    public func runLifecycle(_ phase: LifecyclePhase) async throws
    public func describeRoutes() -> [RouteDescription]
    public func respond(to request: Request) async -> Response
}
```

Rules:

- `respond(to:)` catches framework errors and always returns a `Response`.
- It is the in-memory test surface for runtime behavior.
- Application middleware wraps every request, including missing routes and error responses produced by router dispatch.
- `Application(dependencies:)` configures an app-wide default dependency registry.
- `Application { ... }` remains supported and creates an empty dependency registry.
- `respond(to:)` stamps application dependencies onto the request before middleware and router dispatch.
- Lifecycle hooks are async, throwing, and run in registration order within each phase.
- `respond(to:)` does not run lifecycle hooks.
- `describeRoutes()` returns normalized route descriptions and route metadata without invoking handlers.

### Dependencies

```swift
public struct DependencyKey<Value>: Sendable {
    public let name: String

    public init(_ name: String)
}

@propertyWrapper
public struct Dependency<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value, _ key: DependencyKey<Value>)
}

public struct Dependencies: Sendable {
    public init()

    public mutating func register<Value: Sendable>(_ value: Value)
    public mutating func register<Value: Sendable>(_ value: Value, for key: DependencyKey<Value>)
    public func get<Value: Sendable>(_ type: Value.Type = Value.self) -> Value?
    public func get<Value: Sendable>(_ key: DependencyKey<Value>) -> Value?
    public func require<Value: Sendable>(_ type: Value.Type = Value.self) throws -> Value
    public func require<Value: Sendable>(_ key: DependencyKey<Value>) throws -> Value
}

public struct DependencyError: ResponseError {
    public let typeName: String
    public let keyName: String?
    public static func missing<Value>(_ type: Value.Type) -> DependencyError
    public static func missing<Value>(_ key: DependencyKey<Value>) -> DependencyError
    public var status: Status { get }
    public var reason: String { get }
}
```

Rules:

- `Dependencies` is a default Daylily service channel, not mandatory application architecture.
- The MVP stores concrete `Sendable` values by concrete metatype and keyed `Sendable` values by `DependencyKey<Value>`.
- Re-registering the same concrete type replaces the previous value.
- Re-registering the same typed key replaces the previous keyed value.
- Keyed identity includes both the `Value` type and key name.
- Typed keys support protocol-oriented lookup through existential values such as `DependencyKey<any ProductServing>`.
- Typed keys support same-type multi-instance lookup through distinct key names.
- `Dependency` is the `@Dependency` macro marker for keyed handler parameter injection.
- `@Dependency(key)` lowers into `Request.dependencies.require(key)`.
- Keyless `@Dependency` inference is not supported.
- `get` returns `nil` when the requested concrete or keyed value is missing.
- `require` throws `DependencyError.missing(...)` when the requested concrete or keyed value is missing.
- Missing keyed dependency errors include both the value type and key name.
- `DependencyError` maps to `500 Internal Server Error`.
- Managed service lifecycle runtime APIs are not part of this MVP.

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
- 0020-008 accepts a future `ApplicationService` and `Application.service(_:)` direction for managed services; it is design-only and not public API yet.
- Managed services belong to `Application`; `Dependencies` remains a lookup channel.

### ServerConfiguration

```swift
public struct ServerConfiguration: Equatable, Sendable {
    public var host: String
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var maxMessagesPerRead: Int
    public var gracefulShutdownSignals: Bool

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true
    )
}
```

Rules:

- `ServerConfiguration` is NIO-free and lives in `DaylilyCore`.
- `Application.run(configuration:)` bridges it into the active transport.
- The default NIO server closes on SIGINT/SIGTERM so `shutdown` and `cleanup` can run.

### Route

```swift
public struct Route: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let handler: Handler
    public let metadata: RouteMetadata

    public init(method: HTTPMethod, path: String, handler: Handler, metadata: RouteMetadata = .empty)

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> R,
        metadata: RouteMetadata = .empty
    )

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable () async throws -> R,
        metadata: RouteMetadata = .empty
    )

    public func prefixed(with prefix: String) -> Route
    public func middleware<M: Middleware>(_ middleware: M) -> Route
    public func withMetadata(_ metadata: RouteMetadata) -> Route
    public func describe(
        summary: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        operationID: String? = nil,
        inputs: [RouteInputMetadata] = [],
        requestBody: RouteBodyMetadata? = nil,
        responses: [RouteResponseMetadata] = []
    ) -> Route
}
```

Path rules:

- Stored paths are normalized to begin with `/`.
- Empty path becomes `/`.
- Group prefixes are joined without duplicate slashes.
- Route middleware runs after application and group middleware.
- Route middleware preserves declaration order.
- Route metadata is preserved by `prefixed(with:)`, group routing, and middleware attachment.
- Route metadata does not affect matching or response behavior.

### Route Metadata

```swift
public struct RouteMetadata: Equatable, Sendable {
    public var summary: String?
    public var description: String?
    public var tags: [String]
    public var operationID: String?
    public var inputs: [RouteInputMetadata]
    public var requestBody: RouteBodyMetadata?
    public var responses: [RouteResponseMetadata]

    public init(
        summary: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        operationID: String? = nil,
        inputs: [RouteInputMetadata] = [],
        requestBody: RouteBodyMetadata? = nil,
        responses: [RouteResponseMetadata] = []
    )

    public static let empty: RouteMetadata
}

public enum RouteInputLocation: String, Equatable, Sendable {
    case path
    case query
    case header
}

public struct RouteInputMetadata: Equatable, Sendable {
    public var location: RouteInputLocation
    public var name: String
    public var typeName: String
    public var required: Bool

    public init(location: RouteInputLocation, name: String, typeName: String, required: Bool = true)
    public static func path(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata
    public static func query(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata
    public static func header(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata
}

public struct RouteBodyMetadata: Equatable, Sendable {
    public var contentType: String
    public var typeName: String
    public var required: Bool

    public init(contentType: String, typeName: String, required: Bool = true)
    public static func json(_ typeName: String, required: Bool = true) -> RouteBodyMetadata
}

public struct RouteResponseMetadata: Equatable, Sendable {
    public var status: Status
    public var contentType: String?
    public var typeName: String?

    public init(status: Status = .ok, contentType: String? = nil, typeName: String? = nil)
    public static func response(_ status: Status = .ok, contentType: String? = nil, type typeName: String? = nil) -> RouteResponseMetadata
}

public struct RouteDescription: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var metadata: RouteMetadata

    public init(method: HTTPMethod, path: String, metadata: RouteMetadata = .empty)
}
```

Rules:

- Runtime route metadata is the source of truth for OpenAPI generation.
- Metadata describes routes but does not change routing, middleware, lifecycle, body, or response behavior.
- `Application.describeRoutes()` returns route descriptions without invoking handlers.
- Path/query/header/body/response metadata uses Swift type names as strings in the first slice.
- Schema derivation is deferred.

### Route DSL

```swift
public func Get<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Get<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Post<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Post<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Put<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Put<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Patch<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Patch<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Delete<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Delete<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Head<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Head<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Options<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable () async throws -> R) -> Route
public func Options<R: ResponseConvertible>(_ path: String, _ handler: @escaping @Sendable (Request) async throws -> R) -> Route
public func Group(_ prefix: String, @RouteBuilder routes: () -> [Route]) -> Routes
```

Current runtime verbs:

- `Get`
- `Post`
- `Put`
- `Patch`
- `Delete`
- `Head`
- `Options`

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
- Middleware may read `request.body`, but `RequestBody` remains one-shot.
- Daylily does not automatically replay consumed request bodies.

Runtime verb boundary:

- `HEAD` and `OPTIONS` are explicit route methods.
- There is no automatic `HEAD -> GET` fallback yet.
- There is no automatic `OPTIONS Allow` response yet.

### Request

```swift
public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: RequestBody
    public let parameters: Parameters
    public let query: QueryParameters
    public let dependencies: Dependencies

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([]),
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil,
        dependencies: Dependencies = Dependencies()
    )

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8],
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil,
        dependencies: Dependencies = Dependencies()
    )

    public func with(parameters: Parameters) -> Request
    public func with(body: RequestBody) -> Request
    public func with(headers: Headers) -> Request
    public func with(dependencies: Dependencies) -> Request

    public func withBufferedBody<R: Sendable>(
        upTo limit: ByteCount,
        _ operation: @Sendable (Request, [UInt8]) async throws -> R
    ) async throws -> R
}
```

Rules:

- Initializers strip query text from `path` and populate `query` when `path` includes `?`.
- Explicit `query:` overrides query text parsed from `path`.
- `with(parameters:)`, `with(body:)`, `with(headers:)`, `with(dependencies:)`, and `withBufferedBody(upTo:_:)` preserve query values.

RequestBody rules:

- `body` is a Daylily-owned `RequestBody`.
- The `[UInt8]` initializer converts bytes into `RequestBody.bytes(...)`.
- `with(parameters:)` preserves the same `RequestBody` storage and one-shot state.
- `with(body:)` replaces only the body and preserves method, path, headers, and parameters.
- `with(headers:)` replaces only headers and preserves method, path, body, parameters, and query.
- `with(dependencies:)` replaces only dependencies and preserves method, path, headers, body, parameters, and query.
- `withBufferedBody(upTo:_:)` consumes the current body, creates a replacement `RequestBody.bytes(...)`, and passes both replacement request and collected bytes to the closure.
- `withBufferedBody(upTo:_:)` requires an explicit `ByteCount` limit.
- The replacement body from `withBufferedBody(upTo:_:)` is still one-shot.
- Limit failures from `withBufferedBody(upTo:_:)` throw `BodyError.tooLarge`.
- `DaylilyNIO` creates streaming bodies through transport SPI; user code sees `RequestBody`.

### RequestBody

```swift
public struct RequestBody: Sendable {
    public static func bytes(_ bytes: [UInt8]) -> RequestBody
    public var bytes: BodyBytes { get }
    public func collect(upTo limit: ByteCount) async throws -> [UInt8]
    public func string(upTo limit: ByteCount) async throws -> String
}
```

Rules:

- `RequestBody` is one-shot.
- Reading `bytes`, `collect(upTo:)`, `string(upTo:)`, or JSON consumes the body.
- A second read throws `BodyError.alreadyConsumed`.
- `RequestBody` is a public value type backed by shared storage.
- Copying `RequestBody` does not reset one-shot state.
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

### RequestBody Transport SPI

```swift
@_spi(Transport)
public static func RequestBody.stream(bufferLimit: ByteCount = .megabytes(1)) -> BodyStream

@_spi(Transport)
public struct BodyStream: Sendable {
    public let body: RequestBody
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
    case head = "HEAD"
    case options = "OPTIONS"
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

### RequestBody JSON Decoding

```swift
public extension RequestBody {
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
- RequestBody collection limit failures keep their `BodyError` mapping.
- Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.
- Request content type is not enforced yet.

### Body Property Wrapper

```swift
@propertyWrapper
public struct Body<Value: Decodable & Sendable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value)
}
```

Rules:

- `Body` is the preferred macro marker for typed JSON body injection.
- It lives in `DaylilyJSON`, not `DaylilyCore`.
- `@DaylilyServer` lowers it into `try await req.json(Type.self)`.
- The marker does not own runtime decode behavior.
- `JSONBody` remains available as a compatibility alias spelling with the same behavior.

## Module DaylilyNIO

### NIOServerConfiguration

```swift
public struct NIOServerConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var maxMessagesPerRead: Int
    public var gracefulShutdownSignals: Bool

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true
    )

    public init(_ configuration: ServerConfiguration)
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

- `run(started:)` binds, calls `started`, and waits for the server channel to close.
- Default SIGINT/SIGTERM handling closes the server channel.
- Signal handling stays in `DaylilyNIO` and does not leak NIO types into user APIs.

Rules:

- This is transport infrastructure.
- Most users should call `Application.run(...)` instead.
- Creates `Request` after NIO request head with a streaming `RequestBody`.
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

- Macro implementations generate code that uses `Application` and runtime route DSL functions.
- `@GROUP` changes generated route paths, not `DaylilyCore`.
- Macro implementations must not replace the runtime route system.

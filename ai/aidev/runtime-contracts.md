# Runtime Contracts

This file defines behavior contracts. If source code disagrees, update source or explicitly revise this document.

## Application Contract

Input:

- A list of `Route` values or a `Routes` group collection.
- A `Request` passed to `respond(to:)`.

Output:

- Always returns a `Response`.

Guarantees:

- Matching route handler is called exactly once.
- Application middleware wraps router dispatch.
- Application middleware can transform missing-route responses.
- `ResponseError` is converted to its status and reason.
- `Abort`, `BodyError`, and `ParameterError` conform to `ResponseError`.
- Unknown errors become `500 Internal Server Error`.
- Missing route becomes `404 Not Found`.
- `respond(to:)` does not run lifecycle hooks.

Extension points:

- error renderer
- lifecycle hooks
- service container

## Lifecycle Contract

Input:

- Lifecycle hooks registered on `Application`.

Output:

- Async throwing lifecycle execution.

Guarantees:

- Supported phases are `configure`, `boot`, `started`, `shutdown`, and `cleanup`.
- Hooks run in registration order within each phase.
- `Application.run` calls `configure` and `boot` before server bind.
- `Application.run` calls `started` after NIO bind succeeds.
- `Application.run` calls `shutdown` after server close.
- `Application.run` calls `cleanup` after shutdown.
- `shutdown` and `cleanup` are attempted if server run fails after boot.
- SIGINT/SIGTERM close the default NIO server channel so lifecycle shutdown can continue.
- Lifecycle APIs do not expose NIO types.

## Server Configuration Contract

Input:

- `ServerConfiguration`.

Output:

- Active transport configuration.

Guarantees:

- `ServerConfiguration` is NIO-free.
- `Application.run(configuration:)` is the explicit server control API.
- `Application.run(host:port:)` remains convenience sugar.
- Defaults preserve the original host, port, backlog, reuse address, max messages per read, and graceful signal behavior.

Known limitations:

- No TLS controls yet.
- No HTTP/2 controls yet.
- No worker thread count controls yet.

Lifecycle limitations:

- No graceful request draining yet.
- No worker or pool integration yet.

## Middleware Contract

Owner:

- `DaylilyCore`

Implemented by:

- `ai/tasks/0009-001-middleware-runtime.md`

Shape:

```swift
public protocol Middleware: Sendable {
    func handle(_ request: Request, next: Handler) async throws -> Response
}
```

Ordering:

```text
Application middleware
-> Router dispatch
   -> Group middleware
   -> Route middleware
   -> Handler
```

Guarantees:

- Application middleware wraps every request, including missing routes.
- Group and route middleware run after route matching so path parameters are available.
- Middleware at the same scope runs in declaration order.
- Middleware can short-circuit by returning a `Response` without calling `next`.
- Middleware can call `next` exactly when it wants downstream processing to continue.
- Middleware may throw, and errors flow through the existing `Application.respond(to:)` mapping.
- Middleware can read `request.body`.
- `request.body` remains one-shot; middleware consumption is visible downstream.
- Daylily does not provide automatic body replay.

Extension points:

- macro middleware syntax
- request context
- dependency injection
- explicit body replay helper
- production middleware packages

## Observability Contract

Owner:

- `DaylilyObservability`

Implemented by:

- `ai/tasks/0013-001-request-logging-middleware.md`
- `ai/tasks/0013-002-request-id-and-timing.md`

Shape:

```swift
public struct RequestLog: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var status: Status
    public var requestID: String?
    public var correlationID: String?
    public var durationNanoseconds: UInt64?
    public var errorReason: String?
}

public protocol RequestLogSink: Sendable {
    func record(_ log: RequestLog) async
}

public struct RequestLoggingMiddleware<Sink: RequestLogSink>: Middleware
public struct RequestIDMiddleware: Middleware
```

Guarantees:

- Request logging is implemented as normal middleware.
- The middleware calls downstream exactly once when it does not short-circuit by throwing before `next`.
- `RequestIDMiddleware` generates a Daylily-owned `requestID` for every request.
- Incoming `x-request-id` is treated as external `correlationID`, not as Daylily's unique request identity.
- `RequestIDMiddleware` always writes `x-daylily-request-id`.
- `RequestIDMiddleware` preserves incoming `x-request-id` when present.
- `RequestIDMiddleware` writes generated `requestID` to `x-request-id` only when the incoming header is absent.
- Downstream responses record method, path, status, request ID, external correlation ID, duration, and public error reason when status is `4xx` or `5xx`.
- Thrown `ResponseError` values record their public `status` and are rethrown.
- Unknown thrown errors record `500 Internal Server Error` and are rethrown.
- `RequestLoggingMiddleware` measures duration around `next.respond(to:)` and stores nanoseconds.
- `ConsoleRequestLogSink` writes a simple development log line.
- `InMemoryRequestLogSink` stores logs for checks and early tests.

Boundaries:

- `DaylilyObservability` depends on `DaylilyCore`.
- `DaylilyObservability` may use Foundation for default UUID request ID generation.
- `DaylilyCore` does not depend on `DaylilyObservability`.
- No logging backend, metrics backend, tracing SDK, or transport dependency is required by the current observability slice.

Extension points:

- structured log fields
- OpenTelemetry bridge
- metrics hooks

## Route Contract

Input:

- `HTTPMethod`
- path string
- handler closure or `Handler`

Output:

- Normalized route.

Guarantees:

- Stored path starts with `/`.
- Empty path becomes `/`.
- `prefixed(with:)` joins group prefix and route path without duplicate slashes.
- Route middleware runs after application and group middleware.
- Route middleware preserves declaration order.
- Route metadata is preserved when routes are prefixed, grouped, or wrapped with middleware.
- Route metadata does not affect matching or handler execution.
- Runtime DSL supports `Get`, `Post`, `Put`, `Patch`, `Delete`, `Head`, and `Options`.
- `HEAD` and `OPTIONS` are explicit route methods; there is no automatic `HEAD -> GET` fallback or automatic `OPTIONS Allow` response yet.

Extension points:

- route metadata
- OpenAPI metadata
- middleware metadata

## Route Metadata Contract

Owner:

- `DaylilyCore`

Implemented by:

- `ai/tasks/0014-001-route-metadata-runtime.md`

Shape:

```swift
Route.describe(
    summary: "Show user",
    tags: ["Users"],
    inputs: [.path("id", type: "Int")],
    responses: [.response(.ok, contentType: "application/json", type: "UserResponse")]
)

let descriptions = app.describeRoutes()
```

Guarantees:

- `RouteMetadata` stores summary, description, tags, operation ID, inputs, request body metadata, and response metadata.
- `RouteInputMetadata` supports path, query, and header locations.
- `RouteBodyMetadata` supports explicit content type and Swift type name.
- `RouteResponseMetadata` supports status, optional content type, and optional Swift type name.
- `Application.describeRoutes()` returns route descriptions without invoking handlers.
- Group prefixes are visible in described route paths.
- Group and route middleware do not erase metadata.
- Metadata is runtime-owned and does not require macros.
- `@DaylilyServer` may generate route metadata, but it must use the same runtime metadata types as handwritten routes.

Non-goals:

- Rich OpenAPI operation coverage beyond the current metadata fields.
- Deep schema derivation from Swift declarations.
- Documentation UI.

## OpenAPI Document Contract

Owner:

- `DaylilyOpenAPI`

Implemented by:

- `ai/tasks/0014-002-openapi-schema-mvp.md`

Shape:

```swift
let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
```

Guarantees:

- `Application.openAPI(title:version:)` reads `Application.describeRoutes()`.
- The generated document uses OpenAPI `3.1.0` by default.
- Daylily route paths such as `/users/:id` become OpenAPI paths such as `/users/{id}`.
- Route summary, description, operation ID, and tags map to operation metadata.
- Path, query, and header metadata map to OpenAPI parameters.
- Path parameters are always required in the generated document.
- Request body metadata maps to OpenAPI request body content.
- Response metadata maps to OpenAPI responses.
- Routes without response metadata get a default `200 OK` response.
- Known scalar Swift type names map to simple OpenAPI schemas.
- Unknown Swift type names map to object schemas with `x-swift-type`.
- Macro-generated typed input metadata is consumed the same way as handwritten route metadata.

Non-goals:

- Deep schema derivation from Swift declarations.
- Validation rules.
- Security schemes.
- Documentation UI.
- Client SDK generation.

## Routes Contract

Input:

- A route group prefix.
- Child routes from a `RouteBuilder`.

Output:

- A `Routes` group collection accepted by `RouteBuilder`.

Guarantees:

- Group prefixes are applied to child routes.
- Group middleware is applied before route middleware.
- Chained group middleware preserves declaration order.
- Nested group middleware resolves from outer group to inner group to route.

Extension points:

- route collection metadata
- macro middleware attributes
- OpenAPI group metadata

## Handler Contract

Input:

- `Request`

Output:

- `Response`

Guarantees:

- Supports handlers with request parameter.
- Supports handlers without request parameter.
- Supports async and throwing handlers through closure typing.
- Converts return values using `ResponseConvertible`.

Extension points:

- parameter extraction
- body decoding
- service injection
- macro-generated adapters

## Router Contract

Input:

- `Request.method`
- `Request.path`
- registered routes

Output:

- matching route and extracted parameters, or not found

Guarantees:

- Method must match.
- Path segments must match fully unless wildcard is used.
- Literal segments outrank parameter segments.
- Parameter segments outrank wildcard segments.
- Earlier route wins only when score ties.

Extension points:

- trie/radix implementation
- route conflict diagnostics
- method not allowed response
- host-based routing

## Request Contract

Fields:

- `method`: HTTP method.
- `path`: request path without query string.
- `headers`: normalized headers.
- `body`: Daylily-owned `RequestBody`.
- `parameters`: path parameters populated by router.
- `query`: parsed query parameters.

Guarantees:

- Initializers strip query text from `path` and populate `query` when `path` contains `?`.
- `with(parameters:)` returns a new request preserving method, path, headers, body, and query.
- Preserved body uses shared one-shot state.
- `with(body:)` returns a new request preserving method, path, headers, parameters, and query while replacing body.
- `with(headers:)` returns a new request preserving method, path, body, parameters, and query while replacing headers.
- `withBufferedBody(upTo:_:)` consumes the current body under an explicit limit.
- `withBufferedBody(upTo:_:)` passes collected bytes and a replacement request to the operation closure.
- The replacement request uses `RequestBody.bytes(collectedBytes)`.
- Replacement bodies remain one-shot.
- Over-limit buffering throws `BodyError.tooLarge`, which renders as `413 Payload Too Large`.

Query and header behavior:

- `QueryParameters.require(_:as:)` throws `QueryParameterError.missing` or `.invalid`.
- `Headers.require(_:as:)` throws `HeaderError.missing` or `.invalid`.
- Header names remain case-insensitive.

Transport behavior:

- `DaylilyNIO` creates `Request` after receiving the request head.
- Network requests use a streaming `RequestBody` fed by NIO body chunks.
- In-process callers may still construct buffered bodies with `RequestBody.bytes(...)`.

Extension points:

- JSON body decoding customization
- streaming body
- cookies
- remote address
- request context

## RequestBody Contract

Owner:

- `DaylilyCore`

Types:

- `RequestBody`
- `BodyBytes`
- `ByteChunk`
- `ByteCount`
- `BodyError`

Guarantees:

- `RequestBody` is the single request body abstraction.
- `RequestBody` is public value type backed by shared storage.
- `RequestBody` is uniformly one-shot.
- Copying `RequestBody` does not bypass one-shot consumption.
- `RequestBody.bytes` returns `BodyBytes`.
- `BodyBytes.Element` is `ByteChunk`.
- `ByteChunk` exposes `bytes` and `count`.
- `ByteChunk` does not conform to `Collection` in the first version.
- `RequestBody.collect(upTo:)` requires an explicit `ByteCount` limit.
- `RequestBody.string(upTo:)` requires an explicit `ByteCount` limit.
- `RequestBody.string(upTo:)` is strict UTF-8 and throws `BodyError.invalidEncoding` on invalid bytes.
- Buffered bodies yield at most one `ByteChunk`.
- Streaming bodies yield transport-fed `ByteChunk` values in order.
- Transport-only stream creation and writing uses `@_spi(Transport)` hooks, not normal user API.

Error mapping:

- `BodyError.tooLarge` maps to `413 Payload Too Large` with `Request body too large`.
- `BodyError.alreadyConsumed` maps to `500 Internal Server Error` with `Request body already consumed`.
- `BodyError.streamFailed` maps to `400 Bad Request` with `Request body stream failed`.
- `BodyError.invalidEncoding` maps to `400 Bad Request` with `Invalid UTF-8 body`.

## Response Contract

Fields:

- `status`
- `headers`
- `body`

Guarantees:

- `Response.text` sets `content-type` to `text/plain; charset=utf-8` if absent.
- `bodyString` decodes body bytes as UTF-8.

Extension points:

- JSON response customization
- streaming response
- file response
- response compression

## JSON Contract

Owner:

- `DaylilyJSON`

Inputs:

- `RequestBody` bytes collected under an explicit limit for decode.
- `Encodable & Sendable` values for encode.

Outputs:

- Decoded `Decodable` values from `request.body.json(Type.self, upTo:)`.
- Decoded `Decodable` values from convenience `request.json(Type.self, upTo:)`.
- `Response` values from `JSON(value)`.

Guarantees:

- `request.body.json(Type.self, upTo:)` uses Foundation `JSONDecoder`.
- `request.json(Type.self)` delegates to `request.body.json(Type.self, upTo: .megabytes(1))`.
- Default JSON body limit is 1 MB.
- Decode failures throw `Abort(.badRequest, reason: "Invalid JSON body")`.
- `JSON(value)` uses Foundation `JSONEncoder`.
- `JSON(value)` sets `content-type: application/json` if the response does not already provide a content type.
- JSON support does not add Foundation to `DaylilyCore`.

Known limitations:

- Request content type is not enforced yet.
- There is no custom encoder/decoder configuration API yet.
- Daylily does not automatically make every `Encodable` a `ResponseConvertible`.

Extension points:

- configurable encoders and decoders
- content type enforcement
- body size limits
- streaming JSON
- automatic macro body decoding

## Headers Contract

Input:

- header name/value pairs

Guarantees:

- Header names are normalized to lowercase.
- Subscript lookup is case-insensitive through normalization.

Known limitation:

- Multiple values for one header name are not represented yet.

## Parameters Contract

Input:

- extracted path parameter dictionary

Guarantees:

- Supports string lookup.
- Supports dynamic member lookup.
- Missing parameter returns `nil`.
- Supports typed required extraction through `require(_:as:)`.
- Supports typed optional extraction through `get(_:as:)`.
- `String`, `Int`, `Double`, and `Bool` are built-in `ParameterDecodable` types.
- Missing required path parameters throw `ParameterError.missing`.
- Invalid typed path parameters throw `ParameterError.invalid`.
- `ParameterError` maps to `400 Bad Request`.
- `UUID` is not supported in `DaylilyCore` yet.

Extension points:

- typed conversion
- throwing extraction
- macro parameter injection

## NIO Transport Contract

Input:

- HTTP/1.1 network requests.

Output:

- HTTP/1.1 responses.

Guarantees:

- Converts request head into Daylily method, path, headers.
- Removes query string from `Request.path`.
- Creates `Request` after the request head with a streaming `RequestBody`.
- Starts the route handler before the entire request body is received.
- Feeds NIO body chunks into Daylily `BodyBytes` in order.
- Finishes `BodyBytes` when NIO receives request end.
- Fails `BodyBytes` with `BodyError.streamFailed` on channel/protocol errors.
- Uses bounded Daylily buffering plus NIO `autoRead` control for practical backpressure.
- Calls responder asynchronously.
- Writes response status, headers, body, and content length.

Known limitations:

- No TLS.
- No HTTP/2.
- No graceful signal handling.
- No configurable backlog or worker count beyond current defaults.

Extension points:

- response body streaming
- graceful shutdown
- TLS
- HTTP/2
- alternate transports

## DaylilyTesting Contract

Input:

- An `Application`.
- In-memory `Request` values, `TestRequest` values, or convenience method/path calls.

Output:

- Daylily `Response` values.

Guarantees:

- `TestClient` calls `Application.respond(to:)` directly.
- `TestClient` is transport-free and opens no sockets.
- `TestClient` depends on `DaylilyCore`, not NIO.
- `send(_:)` sends a `TestRequest` by converting it to a runtime `Request`.
- `get(_:)` sends a GET request with optional headers.
- `post(_:body:)` sends a POST request with optional headers and a `RequestBody`, `[UInt8]`, or `String`.
- `put(_:body:)` sends a PUT request with optional headers and a `RequestBody`, `[UInt8]`, or `String`.
- `patch(_:body:)` sends a PATCH request with optional headers and a `RequestBody`, `[UInt8]`, or `String`.
- `delete(_:)`, `head(_:)`, and `options(_:)` send requests with optional headers.
- `postJSON(_:headers:body:)` encodes an `Encodable` body and sets `content-type: application/json` when absent.
- `Response.json(_:)` decodes response bytes with Foundation `JSONDecoder`.
- `requireStatus(_:)`, `requireBody(_:)`, and `requireJSON(_:as:)` throw `TestFailure` when assertions fail.
- Missing routes and thrown framework errors map exactly as `Application.respond(to:)` maps them.

Known limitations:

- Request bodies remain one-shot after a built request is sent.

Extension points:

- typed response helpers
- broader Swift Testing coverage

## Macro Route Contract

Input:

- A declaration group annotated with `@DaylilyServer`.
- Instance methods annotated with `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`, `@HEAD`, or `@OPTIONS`.

Output:

- A generated `static func main() async throws`.

Guarantees:

- Generated code creates `let server = Self()`.
- Generated code creates `Application { ... }`.
- `@GET` lowers to runtime `Get`.
- `@POST` lowers to runtime `Post`.
- `@PUT` lowers to runtime `Put`.
- `@PATCH` lowers to runtime `Patch`.
- `@DELETE` lowers to runtime `Delete`.
- `@HEAD` lowers to runtime `Head`.
- `@OPTIONS` lowers to runtime `Options`.
- `@GROUP` contributes a path prefix for nested route methods.
- Zero-parameter handlers are called as `server.method()`.
- `Request` parameters are called with the route request.
- `@Path` parameters lower into `req.parameters.require(_:as:)`.
- `@Path` names must match `:name` route segments in the full route path.
- `@Query` parameters lower into `req.query.require(_:as:)`.
- `@Header` parameters lower into `req.headers.require(_:as:)`.
- `@Body` parameters lower into `try await req.json(Type.self)`.
- `@JSONBody` remains as a compatibility alias spelling with the same lowering.
- A handler may have at most one `@Body` or `@JSONBody` parameter.
- Grouped handlers are called on default-initialized group instances.

Known limitations:

- Server type must be default-initializable.
- Group types must be default-initializable.
- Static route handlers are not supported.
- Optional typed inputs, macro middleware attributes, and DI are not supported yet.
- OpenAPI metadata lowering exists for typed inputs; deeper schema inference and richer operation metadata are deferred.

Extension points:

- more macro typed input families
- macro middleware attributes
- richer route metadata
- better diagnostics

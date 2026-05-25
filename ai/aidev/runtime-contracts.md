# Runtime Contracts

This file defines behavior contracts. If source code disagrees, update source or explicitly revise this document.

## Application Contract

Input:

- A list of `Route` values.
- A `Request` passed to `respond(to:)`.

Output:

- Always returns a `Response`.

Guarantees:

- Matching route handler is called exactly once.
- `ResponseError` is converted to its status and reason.
- `Abort` and `BodyError` conform to `ResponseError`.
- Unknown errors become `500 Internal Server Error`.
- Missing route becomes `404 Not Found`.

Extension points:

- error renderer
- middleware pipeline
- lifecycle hooks
- service container

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

Extension points:

- additional HTTP verbs
- route metadata
- OpenAPI metadata
- middleware metadata

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
- `body`: Daylily-owned `Body`.
- `parameters`: path parameters populated by router.

Guarantees:

- `with(parameters:)` returns a new request preserving method, path, headers, and body.
- Preserved body uses shared one-shot state.

Known limitation:

- `DaylilyNIO` still buffers body bytes before creating `Request` in 0008A.
- True transport streaming and backpressure are deferred to 0008B.

Extension points:

- query parameters
- JSON body decoding customization
- streaming body
- cookies
- remote address
- request context

## Body Contract

Owner:

- `DaylilyCore`

Types:

- `Body`
- `BodyBytes`
- `ByteChunk`
- `ByteCount`
- `BodyError`

Guarantees:

- `Body` is the single request body abstraction.
- `Body` is public value type backed by shared storage.
- `Body` is uniformly one-shot.
- Copying `Body` does not bypass one-shot consumption.
- `Body.bytes` returns `BodyBytes`.
- `BodyBytes.Element` is `ByteChunk`.
- `ByteChunk` exposes `bytes` and `count`.
- `ByteChunk` does not conform to `Collection` in the first version.
- `Body.collect(upTo:)` requires an explicit `ByteCount` limit.
- `Body.string(upTo:)` requires an explicit `ByteCount` limit.
- `Body.string(upTo:)` is strict UTF-8 and throws `BodyError.invalidEncoding` on invalid bytes.
- Buffered bodies yield at most one `ByteChunk` in 0008A.

Error mapping:

- `BodyError.tooLarge` maps to `413 Payload Too Large` with `Request body too large`.
- `BodyError.alreadyConsumed` maps to `500 Internal Server Error` with `Request body already consumed`.
- `BodyError.streamFailed` maps to `400 Bad Request` with `Request body stream failed`.
- `BodyError.invalidEncoding` maps to `400 Bad Request` with `Invalid UTF-8 body`.

Known limitation:

- 0008A does not implement true NIO request streaming or backpressure.

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

- `Body` bytes collected under an explicit limit for decode.
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
- Buffers body bytes and creates `Request.body` as `Body.bytes(...)` in 0008A.
- Calls responder asynchronously.
- Writes response status, headers, body, and content length.

Known limitations:

- No TLS.
- No HTTP/2.
- No true request body streaming yet; 0008B owns the bridge.
- No graceful signal handling.
- No configurable backlog or worker count beyond current defaults.

Extension points:

- streaming request body
- graceful shutdown
- TLS
- HTTP/2
- alternate transports

## Macro Route Contract

Input:

- A declaration group annotated with `@DaylilyServer`.
- Instance methods annotated with `@GET` or `@POST`.

Output:

- A generated `static func main() async throws`.

Guarantees:

- Generated code creates `let server = Self()`.
- Generated code creates `Application { ... }`.
- `@GET` lowers to runtime `Get`.
- `@POST` lowers to runtime `Post`.
- `@GROUP` contributes a path prefix for nested route methods.
- Zero-parameter handlers are called as `server.method()`.
- One-parameter handlers must take `Request` and are called with the route request.
- Grouped handlers are called on default-initialized group instances.

Known limitations:

- Server type must be default-initializable.
- Group types must be default-initializable.
- Static route handlers are not supported.
- `@Path`, `@Body`, middleware, DI, and OpenAPI metadata are not supported yet.

Extension points:

- typed parameter extraction
- route metadata
- better diagnostics

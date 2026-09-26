# Reliability and Streaming

These APIs are included in `0.1.0-alpha.2`. The older `0.1.0-alpha.1` predates them. Use Swift 6.3.2 for validation; the package requires Swift tools 6.3.

## Streaming a response

```swift
Get("/events") {
    Response.eventStream { writer in
        try await writer.write(ServerSentEvent(data: "ready", id: "1", event: "status"))
        try await Task.sleep(for: .milliseconds(100))
        try await writer.write(ServerSentEvent(data: "done", id: "2", event: "status"))
    }
}
```

`Response(body: .stream(length: nil) { writer in ... })` supports arbitrary byte streams. Await each write: the transport waits for the socket write before accepting the next chunk. The framework does not run a producer ahead into an unbounded queue. Producers should use cancellation-aware operations and must not escape the writer into background tasks. Concurrent or post-completion writes throw.

Streams are consumed once, including across copies of a response. Buffered responses retain their previous behavior. `response.body` and `response.bodyString` only expose buffered data; they return empty values for a stream. For a test, use an explicit bound:

```swift
import DaylilyTesting

try await textResponse.requireBody("ready", upTo: .kilobytes(16))
let payload = try await jsonResponse.json(MyPayload.self, upTo: .megabytes(1))
```

Collection consumes the stream. Synchronous testing helpers reject streams to prevent an accidental assertion on an empty compatibility view.

HEAD, 204, and 304 responses do not execute the producer. A stream failure after headers closes the connection: it cannot be replaced by a second HTTP error response. When the transport observes a disconnect, it cancels handler and producer tasks cooperatively. Unread input under backpressure can delay EOF detection; this is not instantaneous forced termination. SSE encoding handles multiline data and rejects field injection by stripping line breaks from identifiers/event names; applications own heartbeat timing, reconnection storage, and event IDs.

## OpenAPI response transport

`DaylilyOpenAPITransport()` now forwards generated `HTTPBody` responses as streams, including responses larger than the former default 1 MB buffer. For deliberately buffered behavior use:

```swift
let transport = DaylilyOpenAPITransport(responseBodyPolicy: .collect(upTo: .megabytes(2)))
// Existing explicit responseBodyBufferLimit: calls remain supported.
```

Use [the generated server/client example](examples/openapi-transport.md) for explicit schema components, security schemes, schema validation, and a real HTTP round trip. `@Security` describes a requirement; middleware must still perform authentication.

## Optional inputs

```swift
@GET("/search")
func search(@Query page: Int?, @Header("x-client") client: String?) -> String {
    "page=\(page ?? 1), client=\(client ?? "anonymous")"
}
```

`T?`, `Optional<T>`, and `Swift.Optional<T>` lower into runtime `get(_:as:)` with the wrapped scalar. Missing is `nil`; invalid present values remain `400`. Metadata uses the scalar type and `required: false`. Optional path inputs have a compile-time diagnostic because a matched path segment is required. Optional type aliases, nested optionals, and default-argument decoding are outside this slice.

## Lifecycle recovery

Normal startup remains `configure → boot → bind → started`. Configure failure attempts cleanup. Partial boot or later failure attempts shutdown and cleanup. Every teardown hook is attempted once in registration order, even when another throws. Async teardown is awaited independently of cancellation of the caller.

An isolated failure preserves its original error. Combined execution/teardown failures throw `LifecycleRunError`; `primaryError` preserves the initiating failure and `failures` contains phase, zero-based hook index, and original error. Explicit hooks must tolerate partial startup. The normal server and ServiceLifecycle adapter share the same execution path. Application-owned `ServiceGroup` remains the supported way to compose independently running services.

## Validation

```sh
swift build
swift test
swift run --skip-build HelloDaylily --check
scripts/consumer-smoke-test.sh --mode path --profile current
scripts/template-smoke-test.sh --mode path
scripts/example-smoke-test.sh --mode path
scripts/openapi-smoke-test.sh --mode path
scripts/ai-exercises-smoke-test.sh
```

The transport suite checks real sockets: incremental delivery, slow readers, disconnects, framing, producer errors, pipelining, and bind collisions. Fixed application exercises cover adding an endpoint, substituting a typed dependency, and updating a DTO/schema contract. They are concrete acceptance exercises, not a general agent success-rate benchmark.

Current limits include HTTP/1.1 only, no native TLS, no request-draining deadline, no built-in upload deadline, no deep schema reflection, and no framework-owned ORM/authentication stack.

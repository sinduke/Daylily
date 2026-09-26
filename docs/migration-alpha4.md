# Migrating to 0.1.0-alpha.4

Alpha.4 adds response-write deadlines, bounded response-observer delivery and explicit nullable OpenAPI schemas to alpha.3. Existing ordinary `Application.run` and `ServerConfiguration` calls remain valid, but stalled response writes now expire by default. Public APIs remain experimental. The toolchain requirement is unchanged: Swift 6.3 or later, validated with Swift 6.3.2 on macOS and Linux.

## Pin the version

```swift
.package(url: "https://github.com/sinduke/Daylily.git", exact: "0.1.0-alpha.4")
```

Applications upgrading from an earlier version should also follow the [alpha.3 migration guide](migration-alpha3.md) for inbound deadlines, graceful shutdown and response-transfer observation.

## Review the new defaults

The defaults apply to `app.run()` and `app.run(host:port:)` as well as an otherwise unchanged `ServerConfiguration()`.

| Setting | Default | Upgrade consideration |
| --- | --- | --- |
| `responseWriteTimeout` | 30 seconds | Each pending response head, body chunk and end write/flush gets its own deadline. Slow or stalled readers may now lose their connection. |
| `responseObserverCapacity` | 64 | At most 64 observer callbacks may be in flight across one `NIOHTTPServer` instance. New events are dropped immediately when all slots are occupied. |

Configure the write budget for the application's clients and reverse proxy:

```swift
import Daylily

let app = Application {
    Get("/health") { "ok" }
}

try await app.run(
    configuration: ServerConfiguration(
        responseWriteTimeout: .seconds(60),
        responseObserverCapacity: 64
    )
)
```

`responseWriteTimeout` accepts a positive duration, or `nil` to disable this deadline. Zero and negative values are invalid. It does not limit total response duration, handler execution or idle time between SSE producer writes. Existing inbound deadlines and shutdown grace retain their alpha.3 defaults. The optional ServiceLifecycle adapter forwards the same configuration.

When a write deadline expires, the transport selects the `.failed` transfer outcome, cancels the response producer and closes the connection. Cancellation remains cooperative; the deadline cannot forcibly terminate application code that ignores cancellation.

## Account for dropped observer events

Observer capacity must be positive. Admission happens before the delivery task is created; saturation drops the newest event without creating a waiting task or queue. A callback releases its slot when it returns. Callbacks may overlap and arrive out of order. A callback that never returns retains one slot, but requests and server shutdown do not wait for it.

For monitoring, explicitly compose a `NIOHTTPServer` and read its `responseObserverSnapshot`. The Core-owned `ResponseTransferDeliverySnapshot` contains `capacity`, `inFlight`, `completedEvents` and `droppedEvents`; the property is `nil` when no observer is installed. `Application.run` forwards the configuration but does not expose the server object. These counters describe callback delivery, not HTTP success.

Applications that need durable observation must own buffering, export and exporter shutdown. Increasing capacity does not guarantee delivery. `InMemoryResponseTransferObserver` still retains all delivered events; the delivery bound does not bound application-owned event storage. With no observer, no delivery task is created.

## Model nullable values separately from presence

Use `nullable()` on a concrete schema to accept JSON null in addition to its existing type:

```swift
let note = OpenAPISchema.object(
    properties: ["text": .string().nullable()],
    required: ["text"]
)
```

This exports OpenAPI 3.1 `type: ["string", "null"]`. The `text` property must still be present because it appears in `required`; its value may be null. Removing it from `required` allows absence independently of nullability. `isNullable` reports the concrete type/enum intersection and does not resolve references.

Mark a component schema itself nullable before referencing it. Applying `nullable()` directly to a `$ref` is rejected because a sibling constraint cannot widen the referred schema. General unions and `oneOf`/`anyOf`/`allOf` remain unsupported. Compatibility checks still use the old-client to new-server direction and return exit 2 for unsupported constructs.

Check generated clients against the shapes your application uses. The tested Swift OpenAPI Generator 1.13.1 loses nullable item semantics for the tested `$ref` array shape, so the regression fixture uses inline nullable array elements. Swift Codable optional values also merge absent and null. This addition does not supply a three-state PATCH value or guarantee that every generated decoder enforces required-nullable presence.

## Adopt persistence at the application boundary

The [persistent commerce example](../examples/commerce-api/persistent/README.md) is a separate SwiftPM application. It owns its pinned PostgresNIO client/pool, configuration, initial schema setup, transactions and ServiceGroup lifecycle. HTTP drains before the pool stops. Existing applications do not gain a database dependency from upgrading Daylily; the original in-memory example remains available.

When adapting the example, retain explicit database-operation limits, distinguish liveness from database readiness, and preserve the same idempotency key when retrying an order after an uncertain response. The example uses private networking and has no authentication, inventory reservation or durable SSE replay. Its initial schema setup is not an upgrade migration engine; applications own their database evolution and deployment policy.

See the [alpha.4 capability guide](alpha4-candidate.md), [acceptance results](alpha4-acceptance-results.md) and [API registry](../ai/aidev/api-registry.md) for complete contracts and verification evidence.

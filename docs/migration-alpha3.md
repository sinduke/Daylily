# Migrating to 0.1.0-alpha.3

Alpha.3 adds inbound request deadlines, bounded graceful shutdown and terminal response-transfer observation to alpha.2. Existing ordinary `Application.run` and `ServerConfiguration` calls remain valid, but their default connection and shutdown behavior changes. Public APIs remain experimental. The toolchain requirement is unchanged: Swift 6.3 or later, validated with Swift 6.3.2 on macOS and Linux.

## Pin the release

```swift
.package(url: "https://github.com/sinduke/Daylily.git", exact: "0.1.0-alpha.3")
```

Applications upgrading from alpha.1 should also follow the [alpha.2 migration guide](migration-alpha2.md) for response streams, lifecycle errors and optional inputs.

## Review the new defaults

The defaults apply to `app.run()` and `app.run(host:port:)` as well as an otherwise unchanged `ServerConfiguration()`.

| Setting | Default | Upgrade consideration |
| --- | --- | --- |
| `requestHeaderTimeout` | 15 seconds | A complete request head must arrive within the deadline. This includes a newly accepted idle socket and idle keep-alive after the previous response finishes flushing. |
| `uploadIdleTimeout` | 30 seconds | A stalled upload expires between inbound body chunks while the framework is ready to receive. Framework backpressure pauses this timer. |
| `shutdownGracePeriod` | 10 seconds | Signals and ServiceLifecycle graceful shutdown allow active responses to finish before remaining connections close. |

Header and upload timeouts accept a positive `Duration`, or `nil` to disable that deadline. Zero and negative values are invalid. Shutdown grace accepts a nonnegative duration: `.zero` closes immediately, while `nil` permits an unlimited drain.

Configure values to match the application's clients and reverse proxy:

```swift
import Daylily

let app = Application {
    Get("/health") { "ok" }
}

try await app.run(
    configuration: ServerConfiguration(
        requestHeaderTimeout: .seconds(15),
        uploadIdleTimeout: .seconds(30),
        shutdownGracePeriod: .seconds(10)
    )
)
```

Inbound deadlines do not impose a total handler-execution or outgoing SSE-duration limit. A partial or idle request head expires by closing the connection. An upload timeout can send 408 before response headers; otherwise the connection closes. An early response that abandons unfinished input stops the upload timer.

## Allow for graceful draining

Graceful shutdown stops acceptance, closes idle connections, discards new pipelined work and drains active responses. When grace expires, remaining connections close and handlers/producers receive cooperative cancellation. Cancelling the server task is the immediate force-stop path, including when grace is `nil`.

The grace period bounds transport draining; it is not a deadline for all application teardown hooks. Handlers, producers and cleanup code must cooperate with cancellation. Swift cannot forcibly terminate arbitrary application code that ignores it. Choose an outer deployment stop timeout that also accommodates application cleanup.

The optional ServiceLifecycle adapter accepts the same configuration and observer. Continue using `ServerConfiguration.serviceLifecycleDefault` when `ServiceGroup` owns signals; it disables Daylily's signal handlers while retaining these timeout/grace defaults.

## Opt into transfer observation

Request middleware logs still describe handler/middleware execution. To observe completion of buffered responses and long-lived streams, supply an observer separately from configuration:

```swift
try await app.run(
    configuration: ServerConfiguration(),
    responseObserver: ConsoleResponseTransferObserver()
)
```

`ResponseTransferEvent` reports `completed`, `cancelled` or `failed` independently of HTTP status. Successfully sending an HTTP 500 can be `completed`; a producer failing after HTTP 200 headers can be `failed`. Requests cancelled before a response starts do not create response-transfer events.

`bytesSent` counts body bytes whose transport write/flush succeeded, excluding headers/framing. It does not prove client consumption. `durationNanoseconds` covers transmission through terminal state, excluding handler and observer-delivery time.

The transport selects one terminal event per observed response, then delivers it asynchronously outside the event loop. Delivery may be concurrent or out of order and is **best effort at process exit**; server shutdown does not wait for an observer to finish. Applications own durable buffering and exporter shutdown. The default observer is `nil`, which creates no observation-delivery task. `InMemoryResponseTransferObserver` retains events for tests/small development runs; optional `SwiftLogResponseTransferObserver` integrates with an application-owned logger.

For full runtime semantics and reproducible checks, see [operational readiness](operational-readiness.md), [trial results](operational-trial-results.md), and [contract/AI regression](contract-and-ai-regression.md). Alpha.3 remains HTTP/1.1-only, with no built-in TLS, HTTP/2 or production-capacity guarantee.

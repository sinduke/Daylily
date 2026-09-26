# Operational readiness (after alpha.2)

These APIs belong to the current checkout after `0.1.0-alpha.2`. The published alpha.2 contains the earlier reliability/streaming work; installing that tag does not include this operational increment.

## Bound inbound connections and shutdown

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
    ),
    responseObserver: ConsoleResponseTransferObserver()
)
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `requestHeaderTimeout` | 15 seconds | Time allowed to receive a complete head, including a new idle socket and idle keep-alive after the previous response finishes flushing. |
| `uploadIdleTimeout` | 30 seconds | Time between inbound body chunks while the framework is ready to receive. Framework backpressure pauses the timer. |
| `shutdownGracePeriod` | 10 seconds | Time for active responses to finish after a signal or ServiceLifecycle graceful-shutdown request. |

Header/upload settings accept positive durations or `nil` to disable. Grace accepts nonnegative durations (`.zero` forces immediate close), or `nil` for unlimited drain. Configure these to match proxy and client policies. Incoming deadlines do not impose a total handler execution or outgoing SSE duration limit. An early response that abandons unfinished input cancels the upload timer. A partial/idle head expires by closing the connection; stalled body input may receive 408 before response headers, otherwise the connection closes.

Graceful shutdown stops listening, closes idle connections, and lets active responses finish. New pipelined work is discarded. At expiry, remaining channels close and their handlers/producers are cancelled cooperatively. Task cancellation is the force-stop path, including when grace is unlimited. Application code must cooperate with cancellation; neither the deadline nor Swift cancellation can forcibly terminate arbitrary application code. Lifecycle teardown still runs after transport shutdown and has its own application-owned resource cleanup responsibilities.

The optional ServiceLifecycle adapter accepts the same observer/configuration. Use `ServerConfiguration.serviceLifecycleDefault` to leave signal ownership with your `ServiceGroup`. The application owns the group's shutdown policy and exporter lifecycle.

## Measure actual response transfer

`RequestLoggingMiddleware` measures the handler/middleware interval. A returned SSE response can continue transferring long after that log. `ResponseTransferObserver` instead receives a terminal immutable event from the transport:

- `completed`: the response-end write/flush succeeded, including an ordinary HTTP 4xx or 5xx response.
- `cancelled`: disconnect, timeout or forced closure terminated a response that had started.
- `failed`: the response producer or transport write failed.

`bytesSent` counts successfully flushed body bytes, excluding headers/framing; this is not proof that the client consumed the bytes. `durationNanoseconds` measures transmission until terminal state, excluding handler time and exporter time. Method, path, HTTP status and available request/correlation IDs allow association with handler logs. Requests cancelled before a response begins do not manufacture response events.

The event loop chooses a terminal event once. Delivery runs asynchronously outside it, can arrive out of order, and does not block a new request or server shutdown. Delivery is best effort at process exit. A production exporter owns bounded buffering, redaction, retention and its own flush/shutdown. `InMemoryResponseTransferObserver` is intended for tests and small development runs; it retains observations. `ConsoleResponseTransferObserver` and optional `SwiftLogResponseTransferObserver` provide basic development/backend adapters without global logging bootstrap.

## Reproduce the deployment trial

Prerequisites: Docker engine, Python 3, network access to the official Swift/Caddy images and SwiftPM dependencies. No host Swift installation is needed for this command.

```sh
python3 scripts/deployment-trial.py \
  --duration 300 \
  --artifacts /tmp/daylily-deployment
```

Choose a new or empty artifact directory for each run. The harness snapshots the current sources, builds an independent release-mode SwiftPM executable, starts two unprivileged Linux application containers behind Caddy, and binds all host ports to loopback. The app exposes bounded JSON normalization and incremental task-progress SSE. Diagnostic slow/upload/failure routes exist only for this isolated example. Progress is per request; this is not a durable job service and has no database or authentication system.

Checks run before the requested sustained-traffic interval:

1. Both replicas answer requests; bounded JSON input produces the expected result.
2. SSE arrives incrementally and lasts longer than the trial's two-second inbound deadlines.
3. An early client disconnect increases cancellation observations and releases its still-running producer within three seconds.
4. A slow reader leaves the producer active; cancellation releases it without flushing the whole 256 MiB source.
5. Partial headers and stalled body uploads time out at approximately two seconds.
6. SIGTERM drains an active short request, moves new traffic to the healthy replica, cancels long SSE at the grace deadline, and invokes shutdown/cleanup once. Restarted replicas rejoin the proxy.
7. A post-header producer failure is observed separately from its original HTTP 200 status.
8. Four workers send health, JSON and short SSE traffic for the requested duration; failures, latency, resource snapshots and terminal counters are recorded.

Caddy's event-stream handling flushes SSE without setting a negative `flush_interval`. That setting also changes backend cancellation on client disconnect, so the trial retains normal cancellation behavior. See the official [reverse_proxy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

The artifact directory includes `results.json`, image digests/architecture, source-tree hash, Swift version, dependency resolution, proxy configuration, build/container logs and pre-restart lifecycle evidence. Cleanup removes only the uniquely named resources created by the run; cleanup errors or stopped-event-loop scheduling logs fail the trial. Caddy is pinned by its multi-platform image digest. The Swift toolchain is 6.3.2 and its resolved image identity is recorded.

This is a local Linux container deployment behind a real proxy, not a public cloud release or capacity certification. CI repeats the functional scenarios with 30 seconds of sustained traffic. The manual run uses 300 seconds; neither proves overnight stability, leak freedom or production throughput. TLS termination, external databases, public routing and long-lived workload monitoring require a chosen deployment environment and a separate trial.

## Evidence

See [operational trial results](operational-trial-results.md) and [contract/AI regression](contract-and-ai-regression.md) for actual runs. API changes and operational artifacts remain unreleased until a later version is tagged.

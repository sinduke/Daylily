# Migrating to 0.1.0-alpha.2

Alpha.2 publishes the reliability and ecosystem work completed after alpha.1. Public APIs remain experimental. Use Swift 6.3 or later; the release is validated with Swift 6.3.2 on macOS and Linux.

## Pin the release

```swift
.package(url: "https://github.com/sinduke/Daylily.git", exact: "0.1.0-alpha.2")
```

The umbrella module remains `Daylily`. Import optional adapters explicitly: `DaylilyHTTPTypes`, `DaylilySwiftLog`, `DaylilyServiceLifecycle`, and `DaylilyOpenAPITransport`.

## Response bodies

Existing buffered `Response(body: [UInt8])` calls remain supported. Streams live in `response.responseBody`; `response.body` and `bodyString` are buffered views and return empty values for streams. Assigning `body` replaces the stored body.

Consume a stream once. In tests, use explicit bounded async helpers:

```swift
try await response.requireBody("hello", upTo: .kilobytes(16))
```

`DaylilyOpenAPITransport()` now streams generated responses by default. If an application intentionally requires buffering, use `DaylilyOpenAPITransport(responseBodyPolicy: .collect(upTo: .megabytes(2)))`. Existing explicit `responseBodyBufferLimit:` calls remain supported.

## Lifecycle and cancellation

Shutdown/cleanup hooks are attempted once even when another hook fails. Cleanup is awaited independently of caller cancellation. Combined failures expose `LifecycleRunError`; hooks should tolerate partial startup. Observed socket closure cancels cooperative handlers and response producers. User tasks that ignore cancellation cannot be forcibly terminated.

## Inputs and contracts

Optional query/header inputs accept `T?`, `Optional<T>`, and `Swift.Optional<T>`. Missing values become `nil`; invalid present values still return 400. Optional paths have a compile-time diagnostic. Schema/security components are explicit; `@Security` describes authentication requirements but does not enforce them.

For a complete API overview, see [Reliability and streaming](reliability-and-streaming.md), [generated OpenAPI example](examples/openapi-transport.md), and [release evidence](release-readiness.md).

Alpha.2 remains HTTP/1.1-only. Request deadlines, shutdown draining, and transfer-completion observation are separate follow-up work, not alpha.2 features.

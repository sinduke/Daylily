# Changelog

All notable changes to Daylily will be documented in this file.

Daylily is currently experimental. Public APIs may change before beta or stable release.

## Unreleased

## 0.1.0-alpha.3 - 2026-09-26

### Added

- Add configurable complete-header and upload-idle deadlines, with backpressure-aware timing.
- Drain active responses on graceful shutdown within a configurable period; task cancellation forces closure.
- Add optional response-transfer observations with terminal outcome, flushed body bytes and transfer duration; provide console, in-memory and SwiftLog adapters.
- Add a reproducible two-replica Linux/Caddy API/SSE deployment trial and CI coverage.
- Add directional OpenAPI compatibility checks, real old/new generated-client HTTP regression, and repeated actual AI-edit evidence.

### Compatibility

- Swift tools minimum remains 6.3; validated with Swift 6.3.2 on macOS and Linux.
- New defaults are 15-second complete-header timeout, 30-second upload-idle timeout, and 10-second graceful drain. Header/upload durations accept positive values or `nil`; grace accepts nonnegative values or `nil` for unlimited drain.
- The upload-idle deadline pauses during framework upload backpressure. Inbound deadlines do not cap handler or outgoing SSE lifetime. Task cancellation forces transport closure independently of graceful drain.
- Observers are optional and delivered asynchronously; terminal outcome and flushed body bytes do not imply durable delivery or client consumption.
- See [alpha.3 migration](docs/migration-alpha3.md) for behavioral defaults and deployment/exporter ownership.

## 0.1.0-alpha.2 - 2026-09-26

### Added

- Demand-driven ResponseBody streams, awaited writes, SSE events, explicit bounded async testing helpers, and real socket regressions.
- Explicit OpenAPI schema and security components with validation, and actual generated server/client HTTP example.
- Optional query/header macro inputs and clear optional-path diagnostics.
- Exact revision/release external consumption with independent current and legacy API profiles.
- Reproducible application-change exercises and pinned Swift 6.3.2 CI across macOS/Linux.

### Fixed

- Request/response cancellation on disconnect and cancellation of suspended body producers/readers.
- Bind-failure resource cleanup, response framing, and response writer completion/length errors.
- Shared lifecycle teardown that attempts all hooks exactly once, preserves original failures, and completes after caller cancellation.

### Compatibility

- The package now requires Swift tools 6.3; SwiftSyntax uses stable 603.0.1 or later within 603.x.
- OpenAPITransport streams responses by default. Use an explicit responseBodyBufferLimit or responseBodyPolicy.collect for bounded buffering.
- Synchronous response body views remain buffered-only. Async stream tests must specify a collection limit.

### Previously unreleased

- External SwiftPM consumer smoke test script and CI coverage for local path and released package consumption.
- Minimal app template with `AppCore`, executable startup, in-memory tests, and template smoke validation.
- Commerce API example with products, orders, state, metadata, tests, and example smoke validation.
- Dependency injection design for the first `Dependencies` registry MVP.
- Documentation principle that Daylily defaults are recommended paths, not mandatory application architecture.
- `Dependencies` registry MVP with `Application(dependencies:)`, `Request.dependencies`, `register`, `get`, and `require`.
- Dependency usage guide covering `makeApplication`, test overrides, and when to keep custom service wiring.
- Protocol/keyed dependency design centered on typed `DependencyKey<Value>`.
- Keyed dependency runtime API with `DependencyKey<Value>` and keyed `register`, `get`, and `require`.
- Macro `@Dependency` handler parameters over keyed dependency runtime lookup.
- Macro `@Use` middleware attributes for app, group, and route scope, plus explicit route `@Security` metadata for OpenAPI operation security.
- Lifecycle integration design that keeps service ownership on `Application` and lookup in `Dependencies`.
- Optional `DaylilySwiftLog` adapter with `SwiftLogRequestLogSink` for sending Daylily request logs to SwiftLog.
- Optional `DaylilyServiceLifecycle` adapter with `DaylilyApplicationService` for running Daylily applications inside Swift ServiceLifecycle.
- Optional `DaylilyHTTPTypes` adapter for converting Daylily requests and responses to Swift HTTP Types without lossy method, header, query, or request-target handling.
- Optional `DaylilyOpenAPITransport` adapter for registering Swift OpenAPI Generator server handlers onto Daylily routes.
- Lossless HTTP boundary support for custom method tokens, repeated headers, raw request targets, repeated query parameters, and HTTPTypes pseudo fields.

## 0.1.0-alpha.1 - 2026-05-26

### Added

- Swift Concurrency-first runtime with declarative route DSL.
- NIO-backed HTTP/1.1 server.
- Runtime route metadata and minimal OpenAPI document generation.
- Application, group, and route middleware.
- Request ID and request logging middleware in `DaylilyObservability`.
- Daylily-owned one-shot `RequestBody` model with streaming transport bridge.
- JSON request decoding and `JSON(...)` response helpers.
- Macro route/group MVP with typed `@Path`, `@Query`, `@Header`, and preferred `@Body` JSON body input.
- `@JSONBody` compatibility alias spelling for typed JSON body input.
- `DaylilyTesting` transport-free test helpers.
- AIDEV architecture, registry, task, and playbook documentation for AI-assisted development.
- Beta docs: quickstart, capability matrix, JSON API example, middleware example, and testing example.
- GitHub Actions validation for macOS and Linux.

### Fixed

- Linux build compatibility for DaylilyNIO graceful shutdown signal handling.

### Release Notes

- First public SwiftPM alpha release.
- Public API is still experimental and may change before beta or stable release.

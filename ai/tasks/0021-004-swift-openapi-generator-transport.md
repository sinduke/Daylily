# 0021-004 Swift OpenAPI Generator Transport

Status: implemented
Epic: 0021-ecosystem-compatibility

Goal:

- Add an optional Swift OpenAPI Generator server transport for Daylily.
- Let generated `APIProtocol` handlers register onto Daylily routes.
- Keep Swift OpenAPI Generator and OpenAPIRuntime dependencies outside `DaylilyCore` and the umbrella `Daylily` module.

Scope:

- Add a new `DaylilyOpenAPITransport` product and target.
- Add the official `swift-openapi-runtime` package dependency.
- Implement `DaylilyOpenAPITransport` as an OpenAPIRuntime `ServerTransport`.
- Convert OpenAPI `{id}` path parameters to Daylily `:id` route parameters.
- Convert Daylily requests and responses through `DaylilyHTTPTypes`.
- Bridge Daylily one-shot request bodies to OpenAPIRuntime `HTTPBody`.
- Buffer OpenAPIRuntime response bodies into Daylily `Response` under an explicit limit.
- Add tests and external consumer smoke coverage.
- Update README, docs, capability matrix, release readiness, changelog, and AIDEV registry.

Non-goals:

- Replacing Daylily `Application.run(...)`.
- Replacing Daylily `Request` or `Response`.
- Re-exporting `DaylilyOpenAPITransport` from the umbrella `Daylily` module.
- Adding OpenAPIRuntime imports to `DaylilyCore`.
- Implementing response streaming in Daylily core.
- Supporting mixed path template segments such as `/files/{name}.zip`.
- Running the Swift OpenAPI Generator plugin inside Daylily itself.

Implemented:

- `DaylilyOpenAPITransport` conforms to `ServerTransport`.
- `DaylilyOpenAPITransport.routes()` exposes registered routes.
- `DaylilyOpenAPITransport.application(...)` builds a Daylily `Application` from registered generated handlers.
- Whole-segment OpenAPI path parameters such as `{petId}` map to Daylily `:petId` routes and `ServerRequestMetadata.pathParameters`.
- Unsupported or duplicate path parameter templates throw `DaylilyOpenAPITransportError`.
- External consumer smoke path mode imports and exercises `DaylilyOpenAPITransport`.

Public API:

```swift
public enum DaylilyOpenAPITransportError: Error, Equatable, Sendable {
    case invalidHTTPMethod(String)
    case unsupportedPathTemplate(String)
    case duplicatePathParameter(String)
    case missingPathParameter(String)
}

public final class DaylilyOpenAPITransport: ServerTransport, @unchecked Sendable {
    public init(responseBodyBufferLimit: ByteCount = .megabytes(1))

    public func register(
        _ handler: @Sendable @escaping (
            HTTPRequest,
            HTTPBody?,
            ServerRequestMetadata
        ) async throws -> (HTTPResponse, HTTPBody?),
        method: HTTPRequest.Method,
        path: String
    ) throws

    public func routes() -> [Route]

    public func application(
        dependencies configureDependencies: @Sendable (inout Dependencies) -> Void = { _ in }
    ) -> Application
}
```

Example:

```swift
import Daylily
import DaylilyOpenAPITransport
import Foundation

let transport = DaylilyOpenAPITransport()
let handler = GeneratedAPIHandler()

try handler.registerHandlers(
    on: transport,
    serverURL: URL(string: "/api")!
)

try await transport.application().run()
```

Validation:

- `swift build`
- `swift test`
- `scripts/consumer-smoke-test.sh --mode path`
- `git diff --check`

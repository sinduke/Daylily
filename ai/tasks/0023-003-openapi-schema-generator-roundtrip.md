# 0023-003 OpenAPI Schema and Generator Round Trip

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Make explicitly described Daylily contracts usable by Swift OpenAPI Generator.
- Prove generated server and client interoperability over real HTTP.

Scope:

- Explicit named schema and security scheme components, references, and validation.
- Object properties/required fields, arrays, string enums, scalar schemas, and local references.
- Independent `examples/openapi-service` package using the actual generator plugin.
- Application-owned SwiftLog logger and ServiceGroup in the real HTTP example.
- `scripts/openapi-smoke-test.sh` for isolated path, revision, and exact release consumers.

Non-goals:

- Swift declaration reflection, macro changes, OAuth flow modeling, or full JSON Schema validation.
- Changing OpenAPI transport ownership or startup; response streaming integration belongs to the parent task.

Steps:

- [x] 0023-003.1 Add compatible schema/components APIs and validation.
- [x] 0023-003.2 Cover exported references, invalid schemes, and recursive schemas with focused tests.
- [x] 0023-003.3 Generate server/client code and exercise a real HTTP round trip.
- [x] 0023-003.4 Document APIs, regeneration, limitations, and integration requirements.

Architecture impact:

- Schema authoring stays in DaylilyOpenAPI and reads existing runtime type-name metadata.
- Generator and URLSession client dependencies live only in the independent example.

Public API impact:

- `OpenAPIComponents`, `OpenAPISecurityScheme`, and `OpenAPIValidationError`.
- `OpenAPISchema` object/array/enum/reference authoring while retaining the existing initializer and type property.
- Optional document components; `OpenAPIDocument.validate()`.
- Defaulted components parameter on existing builder/application APIs and new `validatedOpenAPI` entry point.

AIDEV updates required:

- Parent integration updates api-registry, runtime-contracts, registry.yml, project-map, capability matrix, and release documentation.
- Unknown unregistered Swift types retain legacy object/x-swift-type fallback; explicit registration maps matching metadata names to component references.
- Validation checks supported schema structure and registered local references/security names; it is not a complete OpenAPI validator and does not enforce authentication at runtime.

Validation:

- Root build/test/check and shared consumer scripts are coordinated by the parent to avoid SwiftPM lock contention.
- Agent independently runs `scripts/openapi-smoke-test.sh --mode path` in an isolated scratch package.
- `git diff --check`.

Notes:

- No commit or push in this delegated task.
- Agent slice, parent validation, and shared AIDEV integration are complete; see the final evidence in 0023-007.

Implemented API for parent registry integration:

```swift
public struct OpenAPIComponents: Codable, Equatable, Sendable {
    public var schemas: [String: OpenAPISchema]
    public var securitySchemes: [String: OpenAPISecurityScheme]
    public init(schemas: [String: OpenAPISchema] = [:], securitySchemes: [String: OpenAPISecurityScheme] = [:])
    public mutating func registerSchema(_ schema: OpenAPISchema, named name: String)
    public mutating func registerSecurityScheme(_ scheme: OpenAPISecurityScheme, named name: String)
}
public struct OpenAPISchema: Codable, Equatable, Sendable {
    // Existing type: String, format, swiftType, and initializer remain.
    public var properties: [String: OpenAPISchema]?
    public var required: [String]?
    public var items: OpenAPISchema?
    public var enumValues: [String]?
    public var reference: String?
    public static func object(properties: [String: OpenAPISchema], required: [String] = []) -> Self
    public static func array(items: OpenAPISchema) -> Self
    public static func string(enum values: [String]? = nil) -> Self
    public static func reference(_ componentName: String) -> Self
}
public struct OpenAPISecurityScheme: Codable, Equatable, Sendable {
    public enum APIKeyLocation: String, Codable, Sendable { case header, query, cookie }
    public var type: String
    public var scheme: String?
    public var bearerFormat: String?
    public var name: String?
    public var location: APIKeyLocation?
    public init(type: String, scheme: String? = nil, bearerFormat: String? = nil, name: String? = nil, location: APIKeyLocation? = nil)
    public static func bearer(format: String? = nil) -> Self
    public static var basic: Self { get }
    public static func apiKey(name: String, location: APIKeyLocation = .header) -> Self
}
public struct OpenAPIValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    public let location: String
    public let reason: String
    public init(location: String, reason: String)
    public var description: String { get }
}
public extension OpenAPIDocument {
    // New optional components property and defaulted components initializer parameter.
    func validate() throws
}
public extension Application {
    func openAPI(title: String, version: String, openapi: String = "3.1.0", components: OpenAPIComponents = .init()) -> OpenAPIDocument
    func validatedOpenAPI(title: String, version: String, openapi: String = "3.1.0", components: OpenAPIComponents = .init()) throws -> OpenAPIDocument
}
// OpenAPIBuilder gains public var components and init(components: OpenAPIComponents = .init()).
```

Validation results:

- 2026-09-26: revalidated the complete external `scripts/openapi-smoke-test.sh --mode path` from a fresh scratch package on Swift 6.3.2 / Xcode 26.5. Generated server/client GET and POST requests passed over real HTTP; started, shutdown, and cleanup were each verified exactly once in order. The exported specification matches checked-in JSON byte for byte.
- 2026-09-26: all six focused schema tests passed from an isolated package. Corrected non-OAuth security requirement validation: OpenAPI 3.1 permits role names, while 3.0 requires empty arrays. Reference: https://spec.openapis.org/oas/v3.1.0.html#security-requirement-object.
- 2026-09-26: revision/release manifest generation passed `swift package dump-package`; the script now rejects resolved pins that differ from the requested SHA/version and supports candidate Git repositories with arbitrary directory names. `bash -n` and scoped `git diff --check` passed. Exact Git end-to-end checks passed in parent integration; testing a future release tag remains a post-publication step.
- 2026-09-08: isolated consumer compiled the actual OpenAPIGenerator 1.13.1 plugin output; generated GET path and POST JSON requests passed through URLSessionTransport, DaylilyOpenAPITransport, NIO, and an application-owned ServiceGroup with SwiftLog request records and graceful shutdown.
- 2026-09-08: all six OpenAPISchemaTests passed from an isolated scratch consumer using the current Daylily source dependency (Xcode 26.5 toolchain).
- 2026-09-08: the complete `scripts/openapi-smoke-test.sh --mode path` passed from a fresh scratch package; checked-in OpenAPI JSON exactly matches the exporter output. `bash -n`, invalid revision argument rejection, and `git diff --check` passed.
- Generated source is under scratch `.build/plugins/outputs/.../GeneratedSources`; checked-in `openapi.json` was produced by `ExportSchema`.
- Generator 1.13.1 emits unused public-import warnings for empty generated component categories with this toolchain; generated code still compiles and runs.
- Exact revision mode requires a Git commit containing these APIs; exact release mode requires a published version. Parent CI verifies the candidate Git revision without publishing a new tag.

Smoke CLI for release/CI integration:

```sh
scripts/openapi-smoke-test.sh --mode path
scripts/openapi-smoke-test.sh --mode path --package-path /absolute/Daylily
scripts/openapi-smoke-test.sh --mode revision --revision FULL_40_CHARACTER_SHA --repo-url URL
scripts/openapi-smoke-test.sh --mode release --version EXACT_VERSION --repo-url URL
```

All modes use identical capabilities. `--workdir` must be new/empty; `--keep` preserves generated artifacts. `OPENAPI_PORT` defaults to 18083, and `DEVELOPER_DIR` can select Xcode. The parent owns adding this command to shared AIDEV/CI/README indexes.

Integration note: implementation, shared documentation, and exact-candidate validation are complete. Task 0023-007 records all eight passing macOS/Linux CI jobs at candidate `7d56798`.

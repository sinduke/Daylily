# 0020-005 Dependencies Registry MVP

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Implement the first Daylily-owned dependency registry.
- Keep the MVP app-wide, concrete-type based, runtime-first, and macro-free.
- Preserve `Application { ... }` and user-owned service wiring as first-class paths.

Scope:

- Add `Dependencies`, `DependencyError`, `register`, `get`, and `require` in `DaylilyCore`.
- Add `Application(dependencies:) { ... }`.
- Add `Request.dependencies`.
- Stamp application dependencies onto each request in `Application.respond(to:)`.
- Cover registry, handler, middleware, and `TestClient` behavior in `DaylilyCheckSuite`.
- Lightly migrate `examples/commerce-api` by registering its existing `CommerceStore`.
- Harden template/example smoke copying so local `.build` artifacts do not enter generated smoke packages.
- Update docs, AIDEV, registry, CI, and release notes.

Non-goals:

- Protocol or existential dependency lookup.
- Keyed dependencies.
- Request-scoped mutation or registration.
- Async factories.
- Lifecycle start/stop integration.
- Hierarchical containers.
- Global singleton registry.
- `@Dependency` macro syntax.
- Requiring applications to use Daylily dependency injection.

Steps:

- [x] 0020-005.1 Add runtime dependency registry API.
- [x] 0020-005.2 Wire dependencies through `Application` and `Request`.
- [x] 0020-005.3 Add behavior checks.
- [x] 0020-005.4 Lightly migrate commerce API.
- [x] 0020-005.5 Update docs and AIDEV.
- [x] 0020-005.6 Validate root package and external example path mode.

Architecture impact:

- `Dependencies` lives in `DaylilyCore`.
- `Application` owns an app-wide `Dependencies` value.
- `Application.respond(to:)` stamps application dependencies onto the incoming request before middleware and routing.
- Middleware and handlers read the same `Request.dependencies`.
- Runtime APIs remain the source of truth; macro syntax is unchanged.

Public API impact:

```swift
public struct Dependencies: Sendable {
    public init()

    public mutating func register<Value: Sendable>(_ value: Value)
    public func get<Value: Sendable>(_ type: Value.Type = Value.self) -> Value?
    public func require<Value: Sendable>(_ type: Value.Type = Value.self) throws -> Value
}

public struct DependencyError: ResponseError {
    public let typeName: String
    public static func missing<Value>(_ type: Value.Type) -> DependencyError
    public var status: Status { get }
    public var reason: String { get }
}

public struct Application: Sendable {
    public init(
        dependencies configureDependencies: @Sendable (inout Dependencies) -> Void = { _ in },
        @RouteBuilder routes: () -> [Route]
    )
}

public struct Request: Sendable {
    public let dependencies: Dependencies
    public func with(dependencies: Dependencies) -> Request
}
```

Behavior:

- `register` stores one value per concrete metatype.
- Re-registering a concrete type replaces the previous value.
- `get` returns `nil` when the concrete type is missing.
- `require` throws `DependencyError.missing(...)` when the concrete type is missing.
- `DependencyError` maps to `500 Internal Server Error`.
- `Application { ... }` remains supported and creates an empty dependency registry.
- The registry is a default Daylily tool, not mandatory application architecture.

Validation:

- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
- `scripts/example-smoke-test.sh --mode path`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode path`
- `bash -n scripts/example-smoke-test.sh scripts/template-smoke-test.sh scripts/consumer-smoke-test.sh`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`

Completed validation:

- Passed `swift build`.
- Passed `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `swift build` in `examples/commerce-api`.
- Passed `swift test` in `examples/commerce-api`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/consumer-smoke-test.sh --mode path`.
- Passed `bash -n scripts/example-smoke-test.sh scripts/template-smoke-test.sh scripts/consumer-smoke-test.sh`.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.

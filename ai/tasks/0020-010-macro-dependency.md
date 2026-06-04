# 0020-010 Macro @Dependency

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Add `@Dependency` handler parameter syntax over the implemented keyed dependency runtime.
- Keep dependency macro syntax as sugar over `Request.dependencies.require(...)`.
- Preserve runtime-first behavior and keep concrete/keyed registry APIs as the source of truth.

Scope:

- Add a public `@Dependency` marker wrapper in `DaylilyCore`.
- Teach `@DaylilyServer` macro lowering to accept `@Dependency(AppDependencies.key)` handler parameters.
- Lower dependency parameters to `try req.dependencies.require(AppDependencies.key)`.
- Support concrete and existential keyed dependency values through `DependencyKey<Value>`.
- Add macro smoke coverage for root and grouped routes.
- Update docs, AIDEV, roadmap, registry, and release readiness.

Non-goals:

- Keyless dependency inference such as `@Dependency service: ProductService`.
- Property injection on route owner types.
- Concrete-type macro lookup without `DependencyKey<Value>`.
- Lifecycle-managed services.
- Async factories.
- Request-scoped dependency registration.
- Default values.
- Direct protocol metatype lookup.
- Middleware macro attributes.

Steps:

- [x] 0020-010.1 Add public `@Dependency` marker API.
- [x] 0020-010.2 Add macro lowering for dependency parameters.
- [x] 0020-010.3 Add macro smoke coverage.
- [x] 0020-010.4 Update docs and AIDEV.
- [x] 0020-010.5 Validate root package and smoke surfaces.
- [x] 0020-010.6 Finish task status.

Architecture impact:

- `Dependency` marker lives in `DaylilyCore` beside `DependencyKey` and `Dependencies`.
- Macro lowering remains in `DaylilyMacros`.
- Runtime dependency lookup remains `Request.dependencies.require(key)`.
- `@Dependency` is optional syntax, not a required application architecture.

Public API impact:

```swift
@propertyWrapper
public struct Dependency<Value: Sendable>: Sendable {
    public var wrappedValue: Value
    public init(wrappedValue: Value, _ key: DependencyKey<Value>)
}
```

Macro shape:

```swift
@GET("/products")
func products(
    @Dependency(AppDependencies.productService) service: any ProductServing
) async throws -> JSON<[Product]> {
    JSON(try await service.list())
}
```

Lowering:

```swift
Get("/products") { req in
    try await server.products(
        service: try req.dependencies.require(AppDependencies.productService)
    )
}
```

Behavior:

- `@Dependency` requires exactly one key expression.
- The key expression is compiled by Swift; the macro does not stringly look up dependencies.
- Missing dependencies continue to map through `DependencyError`.
- `@Dependency` contributes no route metadata.

AIDEV updates required:

- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/project-map.md`
- `ai/aidev/roadmap.md`
- `ai/aidev/start-here.md`
- `ai/aidev/registry.yml`
- README, docs, release readiness, capability matrix, and changelog.

Validation:

- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
- `scripts/consumer-smoke-test.sh --mode path`
- `scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1`
- `scripts/template-smoke-test.sh --mode path`
- `scripts/example-smoke-test.sh --mode path`
- `git diff --check`
- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`

Completed validation:

- Passed `swift build`.
- Passed `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`.
- Passed `swift run HelloDaylily --check`.
- Passed `scripts/consumer-smoke-test.sh --mode path`, including generated macro app HTTP checks for `@Dependency`.
- Passed `scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1`.
- Passed `scripts/template-smoke-test.sh --mode path`.
- Passed `scripts/example-smoke-test.sh --mode path`.
- Passed `bash -n scripts/consumer-smoke-test.sh scripts/template-smoke-test.sh scripts/example-smoke-test.sh`.
- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed stale status scan for current docs claiming `@Dependency` is unimplemented or deferred.

Notes:

- This task depends on `0020-009-keyed-dependencies-runtime`.

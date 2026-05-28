# 0020-007 Protocol / Keyed Dependencies Design

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Design the next dependency registry shape before implementation.
- Support protocol-oriented and same-type multi-instance use cases without turning Daylily into a full DI framework.
- Keep `Dependencies` a default tool, not mandatory application architecture.
- Preserve the concrete-type registry from 0020-005 as the simple path.

Decision:

- Add a future typed key API centered on `DependencyKey<Value>`.
- Do not make protocol metatypes the primary lookup surface.
- Protocol-oriented lookup is expressed by keys whose `Value` is an existential, such as `DependencyKey<any ProductServing>`.
- Same-type multi-instance lookup is expressed by distinct keys with the same value type.
- No default values in the first keyed runtime slice.
- No lifecycle, async factory, request-scoped, or macro syntax in this task.

Proposed future API:

```swift
public struct DependencyKey<Value>: Sendable {
    public let name: String

    public init(_ name: String)
}

public extension Dependencies {
    mutating func register<Value: Sendable>(
        _ value: Value,
        for key: DependencyKey<Value>
    )

    func get<Value: Sendable>(
        _ key: DependencyKey<Value>
    ) -> Value?

    func require<Value: Sendable>(
        _ key: DependencyKey<Value>
    ) throws -> Value
}
```

Example:

```swift
protocol ProductServing: Sendable {
    func list() async throws -> [Product]
}

enum AppDependencies {
    static let productService = DependencyKey<any ProductServing>("productService")
    static let primaryDatabase = DependencyKey<Database>("database.primary")
    static let replicaDatabase = DependencyKey<Database>("database.replica")
}

let app = Application(dependencies: { dependencies in
    dependencies.register(ProductService.live, for: AppDependencies.productService)
    dependencies.register(Database.primary, for: AppDependencies.primaryDatabase)
    dependencies.register(Database.replica, for: AppDependencies.replicaDatabase)
}) {
    Get("/products") { request in
        let service = try request.dependencies.require(AppDependencies.productService)
        return JSON(try await service.list())
    }
}
```

Why not direct protocol lookup:

```swift
dependencies.register(ProductService.live, as: ProductServing.self)
let service = try dependencies.require(ProductServing.self)
```

This reads nicely, but it makes protocol, existential, concrete type, and same-type multi-instance semantics compete for the same lookup surface. It also makes future macro generation less explicit. A typed key keeps the dependency intent visible and gives AI agents a stable symbol to reuse.

Key identity:

- Key identity should include the value type and key name.
- Two keys with the same `Value` and name address the same slot.
- Two keys with different `Value` types and the same name address different slots.
- Re-registering the same key replaces the previous value.
- Missing keyed dependencies should throw a Daylily-owned `DependencyError`.
- Error messages should include the key name and value type.

Naming guidance:

- Put application keys in an app-owned namespace, commonly `enum AppDependencies`.
- Prefer stable lower-camel names for service intent, such as `"productService"`.
- For multiple instances of the same concrete type, use namespaced names such as `"database.primary"` and `"database.replica"`.
- Do not use ad hoc string literals at call sites; define keys once and reuse them.

Concrete registry compatibility:

The concrete-type API remains valid:

```swift
dependencies.register(ProductService.live)
let service = try request.dependencies.require(ProductService.self)
```

The keyed API is for cases where the concrete type does not express intent well:

- protocol-oriented services;
- multiple values of the same concrete type;
- future macro syntax;
- AI-generated code that should use stable dependency symbols.

Future `@Dependency` shape:

```swift
@Dependency(AppDependencies.productService)
var productService
```

This is only a design target. The macro must wait until keyed runtime behavior is implemented and tested.

Non-goals:

- Runtime implementation in 0020-007.
- Direct protocol metatype lookup.
- String-only dependency lookup.
- Default values.
- Implicit globals.
- Request-scoped mutation.
- Lifecycle-owned service start/stop.
- Async factories.
- `@Dependency` macro.
- Replacing user-owned composition roots or service containers.

Follow-up:

- 0020-008 should design lifecycle integration separately.
- 0020-009 should revisit `@Dependency` only after the keyed runtime contract is real.

Validation:

- YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- `git diff --check`.
- Trailing whitespace scan for touched docs and AIDEV files.

Completed validation:

- Passed YAML parse for `.github/workflows/ci.yml` and `ai/aidev/registry.yml`.
- Passed `git diff --check`.
- Passed trailing whitespace scan for touched docs and AIDEV files.
- Passed consistency search for stale 0020-007 planned/next markers.

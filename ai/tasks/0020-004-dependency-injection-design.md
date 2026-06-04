# 0020-004 Dependency Injection Design

Status: implemented
Epic: 0020-package-consumer-experience

Goal:

- Converge the first dependency injection shape before implementation.
- Keep the first slice small enough to validate in the minimal app and commerce API example.
- Separate the registry MVP from protocol keys, lifecycle ownership, and macro sugar.

Scope:

- Define the `Dependencies` registry MVP.
- Define the initial `Application(dependencies:)` and `Request.dependencies` direction.
- Define required runtime operations: `register`, `get`, and `require`.
- Define explicit non-goals for 0020-005.
- Define future extension points and task order through `0020-009`.
- Update AIDEV roadmap, registry, runtime contracts, and package consumer epic.

Non-goals:

- Implement dependency injection runtime code.
- Add protocol or keyed dependency lookup.
- Add request-scoped mutation or per-request factories.
- Add automatic service lifecycle management.
- Add `@Dependency` macro syntax.
- Migrate examples in this task.
- Make Daylily's dependency registry mandatory for user applications.

Steps:

- [x] 0020-004.1 Confirm DI order from the external consumer, minimal app, and commerce API shapes.
- [x] 0020-004.2 Define registry MVP and naming.
- [x] 0020-004.3 Define explicit non-goals.
- [x] 0020-004.4 Define future extension points and follow-up task order.
- [x] 0020-004.5 Update AIDEV status and roadmap.
- [x] 0020-004.6 Validate docs and registry.

Design outcome:

- The public concept is `Dependencies`, not `Container`, `Services`, or `ServiceContainer`.
- The first implementation should be an app-wide concrete-type registry.
- The registry is runtime-first and macro-free.
- Handlers, middleware, and tests should read dependencies through `Request.dependencies`.
- `Application` owns the configured registry and stamps it onto each `Request`.
- Tests should override dependencies by constructing an app with alternate registry contents.

Design addendum before 0020-005:

- `Dependencies` is a default path, not a mandatory path.
- The registry MVP limits what Daylily provides first; it does not limit what applications may build themselves.
- Applications may keep their own composition root and capture their own services in route closures.
- Applications may register their own container as one value if that fits their architecture.
- Future `@Dependency` syntax must remain sugar over runtime behavior, not the only way to access dependencies.

Proposed 0020-005 MVP API:

```swift
public struct Dependencies: Sendable {
    public init()

    public mutating func register<Value: Sendable>(_ value: Value)
    public func get<Value: Sendable>(_ type: Value.Type = Value.self) -> Value?
    public func require<Value: Sendable>(_ type: Value.Type = Value.self) throws -> Value
}

public struct Application: Sendable {
    public init(
        dependencies configureDependencies: (inout Dependencies) -> Void = { _ in },
        @RouteBuilder routes: () -> [Route]
    )
}

public struct Request: Sendable {
    public let dependencies: Dependencies
}
```

MVP behavior:

- `register` stores one concrete `Sendable` value per concrete metatype.
- Re-registering the same concrete type replaces the previous value.
- `get` returns `nil` when no value is registered for the concrete type.
- `require` throws a Daylily-owned missing dependency error.
- Missing dependency errors map to `500 Internal Server Error`.
- `Request.dependencies` is read-only in the MVP.
- The dependency registry must remain NIO-free and live in `DaylilyCore`.
- The registry should be safe to copy into requests without exposing mutable shared state to user handlers.

First usage shape:

```swift
struct ProductService: Sendable {
    func list() async -> [Product] {
        []
    }
}

let app = Application(dependencies: { dependencies in
    dependencies.register(ProductService())
}) {
    Get("/products") { request in
        let service = try request.dependencies.require(ProductService.self)
        return JSON(await service.list())
    }
}
```

Recommended app factory shape:

```swift
func makeApplication(
    configureDependencies: (inout Dependencies) -> Void = { _ in }
) -> Application {
    Application(dependencies: configureDependencies) {
        // routes
    }
}
```

Test override shape:

```swift
let app = makeApplication { dependencies in
    dependencies.register(ProductService.preview)
}
```

0020-005 non-goals:

- No protocol or existential lookup.
- No keyed dependencies.
- No `@Dependency` macro.
- No property-wrapper injection in handlers.
- No lifecycle start/stop management.
- No async factories.
- No request-scoped registration API.
- No hierarchical containers.
- No global singleton registry.
- No requirement that applications use Daylily dependency injection.

Future extension sequence:

```text
0020-005 Dependencies Registry MVP
0020-006 DI Usage Polish
0020-007 Protocol / Keyed Dependencies Design
0020-008 Lifecycle Integration Design
0020-009 Keyed Dependencies Runtime
0020-010 Macro @Dependency
```

Future extension points:

- Protocol and existential lookup with an explicit key model.
- Named or typed keys for multiple values of the same protocol.
- Request-scoped values after the app-wide registry proves useful.
- Lifecycle-aware services after explicit lifecycle ownership is designed.
- Macro `@Dependency` sugar only after runtime APIs and keyed semantics are stable.

Architecture impact:

- Confirms that DI belongs in `DaylilyCore`.
- Keeps the runtime registry as the source of truth.
- Keeps macros as a later sugar layer.
- Avoids introducing lifecycle semantics into the registry MVP.

Public API impact:

- None in this task.
- 0020-005 is expected to add the first public `Dependencies` runtime API.

AIDEV updates required:

- Update 0020 epic task order.
- Update roadmap next recommended task to `0020-005-dependencies-registry-mvp`.
- Update registry decisions for the DI design and task sequence.
- Update runtime contracts with planned dependency registry behavior.

Validation:

- `git diff --check`
- YAML parse for `ai/aidev/registry.yml`

Completed validation:

- `git diff --check`
- No trailing whitespace in changed docs.
- YAML parse for `ai/aidev/registry.yml`
- No stale old DI runtime task names or planned `0020-004` references remain.
- 0020-005 preflight docs calibration: `Dependencies` is documented as a default path, not mandatory architecture.

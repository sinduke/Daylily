# Dependencies Usage

Daylily's `Dependencies` registry is a small default tool for service wiring. It
is not a required application architecture.

Use it when an app-wide concrete `Sendable` service should be available to
handlers and middleware through `Request.dependencies`.

## Application Factory Pattern

Keep application construction behind a project-owned `makeApplication` function.
Use domain-specific parameters for the common case, then delegate to
`configureDependencies` for advanced overrides:

```swift
public func makeApplication(productService: ProductService = .live) -> Application {
    makeApplication(configureDependencies: { dependencies in
        dependencies.register(productService)
    })
}

public func makeApplication(
    configureDependencies: @Sendable (inout Dependencies) -> Void
) -> Application {
    Application(dependencies: configureDependencies) {
        Get("/products") { request in
            let service = try request.dependencies.require(ProductService.self)
            return JSON(try await service.list())
        }
    }
}
```

This keeps startup, tests, and command-line checks using the same app factory,
while leaving the project's composition root in charge.

## Test Overrides

Prefer the domain-specific factory parameter when the test is replacing a normal
business service:

```swift
@Test("products can be listed")
func productsCanBeListed() async throws {
    let service = ProductService.stub([
        Product(id: 1, name: "Preview Tea")
    ])
    let client = TestClient(makeApplication(productService: service))

    let response = try await client.get("/products")

    try response.requireStatus(.ok)
}
```

Use `configureDependencies` when the test needs to exercise the registry itself
or override several dependencies at once:

```swift
let client = TestClient(makeApplication(configureDependencies: { dependencies in
    dependencies.register(ProductService.stub([]))
    dependencies.register(Clock.fixed)
}))
```

## Custom Service Wiring

Capturing your own services remains equally valid:

```swift
let services = MyServices()

let app = Application {
    Get("/products") { _ in
        JSON(try await services.products.list())
    }
}
```

Use the registry when it makes common wiring easier. Use your own composition
root when that makes the application clearer.

## Protocols and Multiple Instances

The current runtime registry looks up concrete types. Protocol-oriented lookup
and multiple values of the same concrete type are designed, but not implemented
yet.

The planned direction is a typed `DependencyKey<Value>`:

```swift
protocol ProductServing: Sendable {
    func list() async throws -> [Product]
}

enum AppDependencies {
    static let productService = DependencyKey<any ProductServing>("productService")
    static let primaryDatabase = DependencyKey<Database>("database.primary")
    static let replicaDatabase = DependencyKey<Database>("database.replica")
}
```

Future usage would look like this:

```swift
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

This keeps dependency intent explicit without making protocol metatypes or raw
strings the main lookup surface.

## Lifecycle

The current registry is an access channel, not a lifecycle owner. If a service
needs explicit startup or shutdown today, keep that in the application
composition root:

```swift
let database = Database.live

let app = Application(dependencies: { dependencies in
    dependencies.register(database)
}) {
    Get("/products") { request in
        let database = try request.dependencies.require(Database.self)
        return JSON(try await database.products())
    }
}
.boot {
    try await database.connect()
}
.shutdown {
    try await database.close()
}
```

The planned lifecycle direction keeps that boundary: `Application` owns service
lifecycle, while `Dependencies` only owns lookup.

```swift
public protocol ApplicationService: Sendable {
    func boot() async throws
    func shutdown() async throws
}
```

Future usage may look like this:

```swift
let database = Database.live
let worker = OrderWorker(database: database)

let app = Application(dependencies: { dependencies in
    dependencies.register(database)
}) {
    // routes
}
.service(database)
.service(worker)
```

Services would boot in registration order and shut down in reverse order. The
same object may be both a dependency and an application service, but those remain
two separate choices.

## Minimal Template

The minimal app template intentionally keeps its source free of `Dependencies`
for now. The template still validates against the current release tag, and
`Dependencies` was added after `0.1.0-alpha.1`.

For a tiny app that needs one shared service, add the factory pattern above to
`templates/minimal-app/Sources/AppCore/App.swift`. For a fuller reference, see
the commerce API example.

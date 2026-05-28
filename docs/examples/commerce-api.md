# Commerce API Example

The first real API example is a small commerce service in
[`examples/commerce-api`](../../examples/commerce-api/README.md).

It is intentionally larger than Hello World but still small enough to read in one
sitting:

- product listing with an optional `category` query parameter;
- typed product and order IDs from route paths;
- JSON request bodies for order creation;
- JSON responses for health, products, and orders;
- explicit route metadata for OpenAPI-facing contracts;
- an actor-backed in-memory store;
- the `Dependencies` registry as a default service channel;
- transport-free tests with `DaylilyTesting`.

## Run It

From the Daylily repository root:

```sh
scripts/example-smoke-test.sh --mode path
```

Or run the example package directly:

```sh
cd examples/commerce-api
swift build
swift test
swift run App --check
swift run App
```

Try it:

```sh
curl http://127.0.0.1:8080/api/health
curl 'http://127.0.0.1:8080/api/products?category=tea'
curl http://127.0.0.1:8080/api/products/1
curl -X POST \
  -H 'content-type: application/json' \
  --data '{"customerEmail":"orders@example.com","items":[{"productID":1,"quantity":2},{"productID":3,"quantity":1}]}' \
  http://127.0.0.1:8080/api/orders
curl http://127.0.0.1:8080/api/orders/1001
```

## Core Shape

```swift
public func makeApplication(store: CommerceStore = .seeded()) -> Application {
    makeApplication(configureDependencies: { dependencies in
        dependencies.register(store)
    })
}

public func makeApplication(
    configureDependencies: @Sendable (inout Dependencies) -> Void
) -> Application {
    Application(dependencies: configureDependencies) {
        Get("/api/products") { request in
            let category = request.query["category"]
            let store = try request.dependencies.require(CommerceStore.self)
            let products = await store.listProducts(category: category)
            return JSON(ProductListResponse(products: products))
        }

        Post("/api/orders") { request in
            let input = try await request.json(CreateOrderRequest.self)
            let store = try request.dependencies.require(CommerceStore.self)
            let order = try await store.createOrder(input)
            return JSON(order, status: .created)
        }
    }
}
```

The example keeps `AppCore` testable and gives `App` only the process startup
responsibility. That is the same external project shape as the minimal template,
but with enough business behavior to guide real applications.

`CommerceStore` is registered through Daylily's default `Dependencies` registry,
but this is not the only valid architecture. A real app can still keep its own
services in a composition root and capture them in route closures when that is
clearer.

Tests use the domain-specific `makeApplication(store:)` override when they only
need a different store. The lower-level `configureDependencies` hook remains
available for tests that need to replace several registered values or exercise
the registry behavior directly.

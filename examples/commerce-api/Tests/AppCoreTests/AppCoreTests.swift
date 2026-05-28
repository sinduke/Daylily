import AppCore
import DaylilyTesting
import Testing

@Test("commerce API lists and filters products")
func commerceAPIListsAndFiltersProducts() async throws {
    let client = TestClient(makeApplication(store: .seeded()))

    let response = try await client.get("/api/products?category=tea")

    try response.requireStatus(.ok)
    let payload = try response.json(ProductListResponse.self)
    #expect(payload.products.map(\.id) == [1, 2])
    #expect(payload.products.allSatisfy { $0.category == "tea" })
}

@Test("commerce API can override dependencies")
func commerceAPICanOverrideDependencies() async throws {
    let store = CommerceStore(
        products: [
            Product(id: 99, name: "Preview Tea", category: "preview", priceCents: 100, inStock: true),
        ]
    )
    let client = TestClient(makeApplication { dependencies in
        dependencies.register(store)
    })

    let response = try await client.get("/api/products?category=preview")

    try response.requireStatus(.ok)
    let payload = try response.json(ProductListResponse.self)
    #expect(payload.products.map(\.id) == [99])
}

@Test("commerce API creates and fetches an order")
func commerceAPICreatesAndFetchesOrder() async throws {
    let client = TestClient(makeApplication(store: .seeded()))
    let input = CreateOrderRequest(
        customerEmail: "orders@example.com",
        items: [
            OrderItemInput(productID: 1, quantity: 2),
            OrderItemInput(productID: 3, quantity: 1),
        ]
    )

    let created = try await client.postJSON("/api/orders", body: input)

    try created.requireStatus(.created)
    let order = try created.json(Order.self)
    #expect(order.id == 1001)
    #expect(order.totalCents == 5_098)
    #expect(order.items.map(\.productID) == [1, 3])

    let fetched = try await client.get("/api/orders/\(order.id)")
    try fetched.requireJSON(order)
}

@Test("commerce API validates order input")
func commerceAPIValidatesOrderInput() async throws {
    let client = TestClient(makeApplication(store: .seeded()))
    let input = CreateOrderRequest(
        customerEmail: "orders@example.com",
        items: [
            OrderItemInput(productID: 1, quantity: 0),
        ]
    )

    let response = try await client.postJSON("/api/orders", body: input)

    try response.requireStatus(.badRequest)
    try response.requireBody("Quantity must be positive")
}

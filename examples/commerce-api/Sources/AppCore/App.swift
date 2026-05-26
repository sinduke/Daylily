import Daylily
import Foundation

public func makeApplication(store: CommerceStore = .seeded()) -> Application {
    Application {
        Get("/api/health") {
            JSON(HealthResponse(status: "ok", service: "commerce-api"))
        }

        Get("/api/products") { request in
            let category = request.query["category"]
            let products = await store.listProducts(category: category)
            return JSON(ProductListResponse(products: products))
        }
        .describe(
            summary: "List products",
            tags: ["Products"],
            inputs: [
                .query("category", type: "String", required: false),
            ],
            responses: [
                .response(.ok, contentType: "application/json", type: "ProductListResponse"),
            ]
        )

        Get("/api/products/:id") { request in
            let id = try request.parameters.require("id", as: Int.self)
            guard let product = await store.product(id: id) else {
                throw Abort(.notFound, reason: "Product not found")
            }

            return JSON(product)
        }
        .describe(
            summary: "Get product",
            tags: ["Products"],
            inputs: [
                .path("id", type: "Int"),
            ],
            responses: [
                .response(.ok, contentType: "application/json", type: "Product"),
                .response(.notFound, contentType: "text/plain", type: "Error"),
            ]
        )

        Post("/api/orders") { request in
            let input = try await request.json(CreateOrderRequest.self)
            let order = try await store.createOrder(input)
            return JSON(order, status: .created)
        }
        .describe(
            summary: "Create order",
            tags: ["Orders"],
            requestBody: .json("CreateOrderRequest"),
            responses: [
                .response(.created, contentType: "application/json", type: "Order"),
                .response(.badRequest, contentType: "text/plain", type: "Error"),
                .response(.notFound, contentType: "text/plain", type: "Error"),
            ]
        )

        Get("/api/orders/:id") { request in
            let id = try request.parameters.require("id", as: Int.self)
            guard let order = await store.order(id: id) else {
                throw Abort(.notFound, reason: "Order not found")
            }

            return JSON(order)
        }
        .describe(
            summary: "Get order",
            tags: ["Orders"],
            inputs: [
                .path("id", type: "Int"),
            ],
            responses: [
                .response(.ok, contentType: "application/json", type: "Order"),
                .response(.notFound, contentType: "text/plain", type: "Error"),
            ]
        )
    }
}

public func runCommerceChecks() async throws {
    let app = makeApplication()

    let health = await app.respond(to: Request(method: .get, path: "/api/health"))
    try requireStatus(health, .ok)
    try requireJSON(
        health,
        HealthResponse(status: "ok", service: "commerce-api")
    )

    let products = await app.respond(to: Request(method: .get, path: "/api/products?category=tea"))
    try requireStatus(products, .ok)
    let productList = try decodeJSON(products, as: ProductListResponse.self)
    guard productList.products.map(\.id) == [1, 2] else {
        throw ExampleCheckFailure("Expected tea product IDs [1, 2], got \(productList.products.map(\.id))")
    }

    let createOrder = CreateOrderRequest(
        customerEmail: "orders@example.com",
        items: [
            OrderItemInput(productID: 1, quantity: 2),
            OrderItemInput(productID: 3, quantity: 1),
        ]
    )
    let createOrderBody = try JSONEncoder().encode(createOrder)
    let orderResponse = await app.respond(
        to: Request(
            method: .post,
            path: "/api/orders",
            headers: ["content-type": "application/json"],
            body: Array(createOrderBody)
        )
    )
    try requireStatus(orderResponse, .created)

    let order = try decodeJSON(orderResponse, as: Order.self)
    guard order.totalCents == 5_098 else {
        throw ExampleCheckFailure("Expected total 5098 cents, got \(order.totalCents)")
    }

    let fetched = await app.respond(to: Request(method: .get, path: "/api/orders/\(order.id)"))
    try requireStatus(fetched, .ok)
    try requireJSON(fetched, order)

    print("Daylily commerce API checks passed.")
}

public actor CommerceStore {
    private var products: [Int: Product]
    private var orders: [Int: Order]
    private var nextOrderID: Int

    public init(
        products: [Product],
        orders: [Int: Order] = [:],
        nextOrderID: Int = 1001
    ) {
        self.products = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        self.orders = orders
        self.nextOrderID = nextOrderID
    }

    public static func seeded() -> CommerceStore {
        CommerceStore(
            products: [
                Product(id: 1, name: "Jasmine Green Tea", category: "tea", priceCents: 1_299, inStock: true),
                Product(id: 2, name: "Oolong Sampler", category: "tea", priceCents: 1_899, inStock: true),
                Product(id: 3, name: "Ceramic Tasting Cup", category: "tools", priceCents: 2_500, inStock: true),
                Product(id: 4, name: "Seasonal Gift Box", category: "gifts", priceCents: 4_200, inStock: false),
            ]
        )
    }

    public func listProducts(category: String?) -> [Product] {
        products.values
            .filter { product in
                category.map { product.category == $0 } ?? true
            }
            .sorted { $0.id < $1.id }
    }

    public func product(id: Int) -> Product? {
        products[id]
    }

    public func order(id: Int) -> Order? {
        orders[id]
    }

    public func createOrder(_ input: CreateOrderRequest) throws -> Order {
        guard !input.items.isEmpty else {
            throw Abort(.badRequest, reason: "Order must include at least one item")
        }

        var lines: [OrderLine] = []
        var totalCents = 0

        for item in input.items {
            guard item.quantity > 0 else {
                throw Abort(.badRequest, reason: "Quantity must be positive")
            }

            guard let product = products[item.productID] else {
                throw Abort(.notFound, reason: "Product not found")
            }

            guard product.inStock else {
                throw Abort(.badRequest, reason: "Product is out of stock")
            }

            let lineTotal = product.priceCents * item.quantity
            totalCents += lineTotal
            lines.append(
                OrderLine(
                    productID: product.id,
                    name: product.name,
                    quantity: item.quantity,
                    unitPriceCents: product.priceCents,
                    lineTotalCents: lineTotal
                )
            )
        }

        let order = Order(
            id: nextOrderID,
            customerEmail: input.customerEmail,
            status: "accepted",
            items: lines,
            totalCents: totalCents
        )
        orders[order.id] = order
        nextOrderID += 1

        return order
    }
}

public struct HealthResponse: Codable, Sendable, Equatable {
    public let status: String
    public let service: String

    public init(status: String, service: String) {
        self.status = status
        self.service = service
    }
}

public struct ProductListResponse: Codable, Sendable, Equatable {
    public let products: [Product]

    public init(products: [Product]) {
        self.products = products
    }
}

public struct Product: Codable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public let category: String
    public let priceCents: Int
    public let inStock: Bool

    public init(
        id: Int,
        name: String,
        category: String,
        priceCents: Int,
        inStock: Bool
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.priceCents = priceCents
        self.inStock = inStock
    }
}

public struct CreateOrderRequest: Codable, Sendable, Equatable {
    public let customerEmail: String
    public let items: [OrderItemInput]

    public init(customerEmail: String, items: [OrderItemInput]) {
        self.customerEmail = customerEmail
        self.items = items
    }
}

public struct OrderItemInput: Codable, Sendable, Equatable {
    public let productID: Int
    public let quantity: Int

    public init(productID: Int, quantity: Int) {
        self.productID = productID
        self.quantity = quantity
    }
}

public struct Order: Codable, Sendable, Equatable {
    public let id: Int
    public let customerEmail: String
    public let status: String
    public let items: [OrderLine]
    public let totalCents: Int

    public init(
        id: Int,
        customerEmail: String,
        status: String,
        items: [OrderLine],
        totalCents: Int
    ) {
        self.id = id
        self.customerEmail = customerEmail
        self.status = status
        self.items = items
        self.totalCents = totalCents
    }
}

public struct OrderLine: Codable, Sendable, Equatable {
    public let productID: Int
    public let name: String
    public let quantity: Int
    public let unitPriceCents: Int
    public let lineTotalCents: Int

    public init(
        productID: Int,
        name: String,
        quantity: Int,
        unitPriceCents: Int,
        lineTotalCents: Int
    ) {
        self.productID = productID
        self.name = name
        self.quantity = quantity
        self.unitPriceCents = unitPriceCents
        self.lineTotalCents = lineTotalCents
    }
}

private func requireStatus(_ response: Response, _ expected: Status) throws {
    guard response.status == expected else {
        throw ExampleCheckFailure("Expected \(expected.code), got \(response.status.code)")
    }
}

private func requireJSON<Value: Decodable & Equatable>(
    _ response: Response,
    _ expected: Value,
    as type: Value.Type = Value.self
) throws {
    let actual = try decodeJSON(response, as: type)
    guard actual == expected else {
        throw ExampleCheckFailure("Expected JSON \(expected), got \(actual)")
    }
}

private func decodeJSON<Value: Decodable>(
    _ response: Response,
    as type: Value.Type
) throws -> Value {
    do {
        return try JSONDecoder().decode(type, from: Data(response.body))
    } catch {
        throw ExampleCheckFailure("Failed to decode \(type): \(error)")
    }
}

private struct ExampleCheckFailure: Error, Sendable, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

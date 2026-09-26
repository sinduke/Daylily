import AppCore
import Daylily
import PersistentCommerceCore
import Testing

@Test("configuration rejects invalid resource limits instead of silently falling back")
func invalidConfiguration() throws {
    for environment in [
        ["PORT": "0"], ["PGPORT": "abc"], ["PGPOOL_MAX_CONNECTIONS": "0"],
        ["DB_OPERATION_TIMEOUT_MS": "-1"], ["SHUTDOWN_GRACE_MS": "-1"], ["PGSSLMODE": "prefer"],
    ] {
        #expect(throws: ConfigurationError.self) { try CommerceConfiguration(environment: environment) }
    }
    let valid = try CommerceConfiguration(environment: ["PGPOOL_MAX_CONNECTIONS": "1", "SHUTDOWN_GRACE_MS": "0"])
    #expect(valid.database.options.maximumConnections == 1)
    #expect(valid.shutdownGrace == .zero)
}

@Test("untrusted orders have explicit arithmetic and request-size bounds")
func orderValidation() throws {
    let valid = CreateOrderRequest(customerEmail: "orders@example.com", items: [.init(productID: 1, quantity: 1)])
    try PostgresCommerceRepository.validate(valid, idempotencyKey: "abc-123")
    for items in [[], [.init(productID: 1, quantity: 0)], [.init(productID: 1, quantity: Int.max)],
                  Array(repeating: OrderItemInput(productID: 1, quantity: 1), count: 101)] {
        let input = CreateOrderRequest(customerEmail: "orders@example.com", items: items)
        #expect(throws: Abort.self) { try PostgresCommerceRepository.validate(input, idempotencyKey: nil) }
    }
    for key in ["", "a b", String(repeating: "x", count: 129), "含中文"] {
        #expect(throws: Abort.self) { try PostgresCommerceRepository.validate(valid, idempotencyKey: key) }
    }
}

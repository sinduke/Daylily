import TrialApp
import DaylilyCore
import DaylilyTesting
import Foundation
import Testing
@Suite struct ReservationAcceptance {
    func reserve(_ client: TestClient, _ key: String, _ n: Int) async throws -> Response {
        try await client.post("/reservations", body: "{\"key\":\"\(key)\",\"quantity\":\(n)}")
    }
    @Test func atomicConcurrentReservationsAndIdempotency() async throws {
        let store = Inventory(stock: 11)
        let client = TestClient(ReservationApp.application(inventory: store))
        let statuses = try await withThrowingTaskGroup(of: Int.self) { group in
            for i in 0..<24 { group.addTask { try await reserve(client, "key-\(i)", 1).status.code } }
            var values: [Int] = []; for try await v in group { values.append(v) }; return values
        }
        #expect(statuses.filter { $0 == 200 }.count == 11)
        #expect(statuses.filter { $0 == 409 }.count == 13)
        #expect(await store.available() == 0)
        let own = TestClient(ReservationApp.application(inventory: Inventory(stock: 7)))
        let a = try await reserve(own, "stable", 3)
        let b = try await reserve(own, "stable", 3)
        #expect(a.status.code == 200 && b.status.code == 200)
        let aa = try JSONDecoder().decode(Receipt.self, from: Data(a.body))
        let bb = try JSONDecoder().decode(Receipt.self, from: Data(b.body))
        #expect(aa == bb && aa.remaining == 4)
        #expect(try await reserve(own, "stable", 2).status.code == 409)
        let stock = try await own.get("/stock")
        #expect(try JSONDecoder().decode(Stock.self, from: Data(stock.body)).available == 4)
    }
    @Test func invalidInputPreservesState() async throws {
        let store = Inventory(stock: 5); let client = TestClient(ReservationApp.application(inventory: store))
        #expect(try await reserve(client, "a", 0).status.code == 400)
        #expect(try await reserve(client, "b", -2).status.code == 400)
        #expect(try await reserve(client, "c", 6).status.code == 409)
        #expect(try await client.post("/reservations", body: "not json").status.code == 400)
        #expect(await store.available() == 5)
        try await client.get("/health").requireBody("ok")
    }
}

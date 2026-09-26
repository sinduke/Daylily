import Daylily
import DaylilyTesting
import Testing

@Suite("Optional typed inputs")
struct OptionalInputTests {
    @Test("Runtime optional extraction preserves missing and invalid distinctions")
    func extraction() async throws {
        let app = Application {
            Get("/optional") { request in
                let page = try request.query.get("page", as: Int.self)
                let enabled = try request.headers.get("x-enabled", as: Bool.self)
                return "\(page.map(String.init) ?? "nil"):\(enabled.map(String.init) ?? "nil")"
            }.describe(inputs: [
                .query("page", type: "Int", required: false),
                .header("x-enabled", type: "Bool", required: false),
            ])
        }
        let client = TestClient(app)
        try await client.get("/optional").requireBody("nil:nil")
        try await client.get("/optional?page=2", headers: ["x-enabled": "true"]).requireBody("2:true")
        try await client.get("/optional?page=nope").requireStatus(.badRequest)
        try await client.get("/optional", headers: ["x-enabled": "sometimes"]).requireStatus(.badRequest)
        let document = try app.validatedOpenAPI(title: "Optional", version: "1")
        let inputs = try #require(document.paths["/optional"]?["get"]?.parameters)
        #expect(inputs.map(\.required) == [false, false])
        #expect(inputs.map(\.schema.type) == ["integer", "boolean"])
    }
}

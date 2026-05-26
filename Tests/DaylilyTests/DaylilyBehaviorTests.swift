import Daylily
import DaylilyCheckSuite
import DaylilyTesting
import Testing

@Test("Daylily behavior check suite")
func daylilyBehaviorCheckSuite() async throws {
    try await DaylilyChecks.run()
}

@Test("Formal test target uses DaylilyTesting without opening a port")
func formalTestTargetUsesDaylilyTesting() async throws {
    let app = Application {
        Get("/hello") {
            "Daylily ships."
        }

        Post("/json/echo") { request in
            let input = try await request.json(EchoPayload.self)
            return JSON(EchoResponse(echo: input.message))
        }
    }

    let client = TestClient(app)
    let hello = try await client.get("/hello")
    let echo = try await client.postJSON("/json/echo", body: EchoPayload(message: "testing"))

    #expect(hello.status == .ok)
    #expect(hello.bodyString == "Daylily ships.")
    try echo.requireJSON(EchoResponse(echo: "testing"))
}

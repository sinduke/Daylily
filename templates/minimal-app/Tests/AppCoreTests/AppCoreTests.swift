import AppCore
import DaylilyTesting
import Testing

@Test("minimal Daylily app responds in memory")
func minimalDaylilyAppRespondsInMemory() async throws {
    let client = TestClient(makeApplication())

    let hello = try await client.get("/hello")
    let health = try await client.get("/health")
    let echo = try await client.postJSON("/echo", body: EchoRequest(message: "testing"))

    try hello.requireStatus(.ok)
    try hello.requireBody("Daylily minimal app ships.")
    try health.requireJSON(HealthPayload(status: "ok"))
    try echo.requireJSON(EchoResponse(echo: "testing"))
}

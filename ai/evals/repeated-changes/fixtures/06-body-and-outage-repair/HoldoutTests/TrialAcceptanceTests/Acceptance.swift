import TrialApp
import DaylilyCore
import DaylilyTesting
import Foundation
import Testing
@Suite struct RecoveryAcceptance {
    @Test func bodyReplayAndBoundedAudit() async throws {
        let trail=AuditTrail(); let client=TestClient(RecoveryApp.application(backend: EchoBackend(), audit: trail))
        for text in ["hello", "world", "中文"] {
            let body=try JSONSerialization.data(withJSONObject: ["text": text])
            let response=try await client.post("/echo", body: Array(body))
            #expect(response.status.code == 200)
            if response.status.code == 200 { #expect(try JSONDecoder().decode(EchoOutput.self, from: Data(response.body)).text == text) }
        }
        #expect(await trail.recorded() == 3)
        #expect(try await client.post("/echo", body: "{").status.code == 400)
        #expect(try await client.post("/echo", body: String(repeating: "x", count: 257)).status.code == 413)
        #expect(await trail.recorded() == 4)
    }
    @Test func outagesAreRecoverableAndHealthIndependent() async throws {
        let backend=EchoBackend(available: false)
        let client=TestClient(RecoveryApp.application(backend: backend, audit: AuditTrail()))
        let failed=try await client.post("/echo", body: "{\"text\":\"password=private\"}")
        #expect(failed.status.code == 503)
        #expect(!failed.bodyString.contains("password"))
        #expect(failed.bodyString.contains("Service temporarily unavailable"))
        try await client.get("/health").requireBody("ok")
        await backend.setAvailable(true)
        let recovered=try await client.post("/echo", body: "{\"text\":\"recovered\"}")
        #expect(recovered.status.code == 200)
    }
}

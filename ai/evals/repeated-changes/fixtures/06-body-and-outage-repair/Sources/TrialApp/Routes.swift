import DaylilyCore
import DaylilyJSON
public enum RecoveryApp {
    public static func application(backend: EchoBackend, audit: AuditTrail) -> Application {
        Application {
            Get("/health") { "ok" }
            Post("/echo") { request in
                let input=try await request.json(EchoInput.self)
                return JSON(EchoOutput(text: try await backend.echo(input.text)))
            }.middleware(Audit(trail: audit))
        }
    }
}

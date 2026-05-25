import Daylily

@main
struct HelloDaylily {
    static func main() async throws {
        if CommandLine.arguments.contains("--check") {
            try await DaylilyChecks.run()
            return
        }

        try await makeApplication().run()
    }

    static func makeApplication() -> Application {
        let app = Application {
            Get("/") {
                "Daylily is awake."
            }

            Get("/hello") {
                "Daylily ships."
            }

            Get("/users/:id") { request in
                "User \(request.parameters.id ?? "unknown")"
            }

            Get("/json/health") {
                JSON(HealthPayload(status: "ok"))
            }

            Post("/json/echo") { request in
                let input = try await request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }

            Post("/echo") { request in
                try await request.body.string(upTo: .kilobytes(64))
            }
        }

        return app
    }
}

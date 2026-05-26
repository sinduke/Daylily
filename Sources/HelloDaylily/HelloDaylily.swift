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
                let id = try request.parameters.require("id", as: Int.self)
                return "User \(id)"
            }

            Get("/search") { request in
                let term = try request.query.require("term", as: String.self)
                let page = try request.query.get("page", as: Int.self) ?? 1
                return "Search \(term) page \(page)"
            }

            Get("/headers") { request in
                try request.headers.require("x-daylily", as: String.self)
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

            Post("/upload/count") { request in
                var bytes = 0
                var chunks = 0

                for try await chunk in request.body.bytes {
                    bytes += chunk.count
                    chunks += 1
                }

                return JSON(UploadCountPayload(bytes: bytes, chunks: chunks))
            }
        }

        return app
    }
}

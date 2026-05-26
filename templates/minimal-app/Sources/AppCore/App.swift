import Daylily

public func makeApplication() -> Application {
    Application {
        Get("/hello") {
            "Daylily minimal app ships."
        }

        Get("/health") {
            JSON(HealthPayload(status: "ok"))
        }

        Post("/echo") { request in
            let input = try await request.json(EchoRequest.self)
            return JSON(EchoResponse(echo: input.message))
        }
    }
}

public struct HealthPayload: Codable, Sendable, Equatable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct EchoRequest: Codable, Sendable, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct EchoResponse: Codable, Sendable, Equatable {
    public let echo: String

    public init(echo: String) {
        self.echo = echo
    }
}

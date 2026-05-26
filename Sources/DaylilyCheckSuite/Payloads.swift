public struct HealthPayload: Codable, Equatable, Sendable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct EchoPayload: Codable, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public struct EchoResponse: Codable, Equatable, Sendable {
    public let echo: String

    public init(echo: String) {
        self.echo = echo
    }
}

public struct UploadCountPayload: Codable, Equatable, Sendable {
    public let bytes: Int
    public let chunks: Int

    public init(bytes: Int, chunks: Int) {
        self.bytes = bytes
        self.chunks = chunks
    }
}

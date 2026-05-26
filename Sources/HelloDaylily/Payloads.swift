struct HealthPayload: Codable, Equatable, Sendable {
    let status: String
}

struct EchoPayload: Codable, Equatable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Equatable, Sendable {
    let echo: String
}

struct UploadCountPayload: Codable, Equatable, Sendable {
    let bytes: Int
    let chunks: Int
}

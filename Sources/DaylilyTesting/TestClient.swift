import DaylilyCore

public struct TestClient: Sendable {
    private let application: Application

    public init(_ application: Application) {
        self.application = application
    }

    public func respond(to request: Request) async throws -> Response {
        await application.respond(to: request)
    }

    public func send(_ request: TestRequest) async throws -> Response {
        try await respond(to: request.toRequest())
    }

    public func get(
        _ path: String,
        headers: Headers = [:]
    ) async throws -> Response {
        try await respond(to: Request(method: .get, path: path, headers: headers))
    }

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: Body = .bytes([])
    ) async throws -> Response {
        try await respond(to: Request(method: .post, path: path, headers: headers, body: body))
    }

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: [UInt8]
    ) async throws -> Response {
        try await post(path, headers: headers, body: .bytes(body))
    }

    public func post(
        _ path: String,
        headers: Headers = [:],
        body: String
    ) async throws -> Response {
        try await post(path, headers: headers, body: Array(body.utf8))
    }

    public func postJSON<Value: Encodable>(
        _ path: String,
        headers: Headers = [:],
        body value: Value
    ) async throws -> Response {
        try await send(TestRequest.post(path, headers: headers).withJSON(value))
    }

    public func put(
        _ path: String,
        headers: Headers = [:],
        body: Body = .bytes([])
    ) async throws -> Response {
        try await respond(to: Request(method: .put, path: path, headers: headers, body: body))
    }

    public func put(
        _ path: String,
        headers: Headers = [:],
        body: [UInt8]
    ) async throws -> Response {
        try await put(path, headers: headers, body: .bytes(body))
    }

    public func put(
        _ path: String,
        headers: Headers = [:],
        body: String
    ) async throws -> Response {
        try await put(path, headers: headers, body: Array(body.utf8))
    }

    public func patch(
        _ path: String,
        headers: Headers = [:],
        body: Body = .bytes([])
    ) async throws -> Response {
        try await respond(to: Request(method: .patch, path: path, headers: headers, body: body))
    }

    public func patch(
        _ path: String,
        headers: Headers = [:],
        body: [UInt8]
    ) async throws -> Response {
        try await patch(path, headers: headers, body: .bytes(body))
    }

    public func patch(
        _ path: String,
        headers: Headers = [:],
        body: String
    ) async throws -> Response {
        try await patch(path, headers: headers, body: Array(body.utf8))
    }

    public func delete(
        _ path: String,
        headers: Headers = [:]
    ) async throws -> Response {
        try await respond(to: Request(method: .delete, path: path, headers: headers))
    }

    public func head(
        _ path: String,
        headers: Headers = [:]
    ) async throws -> Response {
        try await respond(to: Request(method: .head, path: path, headers: headers))
    }

    public func options(
        _ path: String,
        headers: Headers = [:]
    ) async throws -> Response {
        try await respond(to: Request(method: .options, path: path, headers: headers))
    }
}

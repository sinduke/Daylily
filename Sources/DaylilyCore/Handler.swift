public struct Handler: Sendable {
    private let closure: @Sendable (Request) async throws -> Response

    public init(_ closure: @escaping @Sendable (Request) async throws -> Response) {
        self.closure = closure
    }

    public func respond(to request: Request) async throws -> Response {
        try await closure(request)
    }
}

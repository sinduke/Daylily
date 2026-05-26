public protocol Middleware: Sendable {
    func handle(_ request: Request, next: Handler) async throws -> Response
}

struct AnyMiddleware: Sendable {
    private let closure: @Sendable (Request, Handler) async throws -> Response

    init<M: Middleware>(_ middleware: M) {
        self.closure = { request, next in
            try await middleware.handle(request, next: next)
        }
    }

    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await closure(request, next)
    }
}

func middlewarePipeline(
    middlewares: [AnyMiddleware],
    terminal: Handler
) -> Handler {
    middlewares.reversed().reduce(terminal) { next, middleware in
        Handler { request in
            try await middleware.handle(request, next: next)
        }
    }
}

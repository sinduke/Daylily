public struct Route: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let handler: Handler
    public let metadata: RouteMetadata
    let middlewares: [AnyMiddleware]

    public init(method: HTTPMethod, path: String, handler: Handler, metadata: RouteMetadata = .empty) {
        self.init(method: method, path: path, handler: handler, metadata: metadata, middlewares: [])
    }

    init(
        method: HTTPMethod,
        path: String,
        handler: Handler,
        metadata: RouteMetadata,
        middlewares: [AnyMiddleware]
    ) {
        self.method = method
        self.path = Route.normalize(path)
        self.handler = handler
        self.metadata = metadata
        self.middlewares = middlewares
    }

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable (Request) async throws -> R,
        metadata: RouteMetadata = .empty
    ) {
        self.init(
            method: method,
            path: path,
            handler: Handler { request in
                try await handler(request).toResponse()
            },
            metadata: metadata
        )
    }

    public init<R: ResponseConvertible>(
        method: HTTPMethod,
        path: String,
        handler: @escaping @Sendable () async throws -> R,
        metadata: RouteMetadata = .empty
    ) {
        self.init(
            method: method,
            path: path,
            handler: Handler { _ in
                try await handler().toResponse()
            },
            metadata: metadata
        )
    }

    public func prefixed(with prefix: String) -> Route {
        Route(method: method, path: Self.join(prefix, path), handler: handler, metadata: metadata, middlewares: middlewares)
    }

    public func middleware<M: Middleware>(_ middleware: M) -> Route {
        addingMiddlewares([AnyMiddleware(middleware)], placement: .append)
    }

    public func withMetadata(_ metadata: RouteMetadata) -> Route {
        Route(method: method, path: path, handler: handler, metadata: metadata, middlewares: middlewares)
    }

    public func describe(
        summary: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        operationID: String? = nil,
        inputs: [RouteInputMetadata] = [],
        requestBody: RouteBodyMetadata? = nil,
        responses: [RouteResponseMetadata] = []
    ) -> Route {
        withMetadata(
            RouteMetadata(
                summary: summary,
                description: description,
                tags: tags,
                operationID: operationID,
                inputs: inputs,
                requestBody: requestBody,
                responses: responses
            )
        )
    }

    func addingGroupMiddlewares(_ middlewares: [AnyMiddleware]) -> Route {
        addingMiddlewares(middlewares, placement: .prepend)
    }

    func respond(to request: Request) async throws -> Response {
        let pipeline = middlewarePipeline(middlewares: middlewares, terminal: handler)
        return try await pipeline.respond(to: request)
    }

    private func addingMiddlewares(
        _ newMiddlewares: [AnyMiddleware],
        placement: MiddlewarePlacement
    ) -> Route {
        let combined: [AnyMiddleware]
        switch placement {
        case .prepend:
            combined = newMiddlewares + middlewares
        case .append:
            combined = middlewares + newMiddlewares
        }

        return Route(method: method, path: path, handler: handler, metadata: metadata, middlewares: combined)
    }

    private static func normalize(_ path: String) -> String {
        let trimmed = trimSlashes(path)
        return trimmed.isEmpty ? "/" : "/" + trimmed
    }

    private static func join(_ prefix: String, _ path: String) -> String {
        let prefix = trimSlashes(prefix)
        let path = trimSlashes(path)

        switch (prefix.isEmpty, path.isEmpty) {
        case (true, true):
            return "/"
        case (true, false):
            return "/" + path
        case (false, true):
            return "/" + prefix
        case (false, false):
            return "/" + prefix + "/" + path
        }
    }

    private static func trimSlashes(_ value: String) -> String {
        var start = value.startIndex
        var end = value.endIndex

        while start < end, value[start] == "/" {
            start = value.index(after: start)
        }

        while end > start {
            let beforeEnd = value.index(before: end)
            guard value[beforeEnd] == "/" else {
                break
            }
            end = beforeEnd
        }

        return String(value[start..<end])
    }
}

private enum MiddlewarePlacement {
    case prepend
    case append
}

public struct Routes: Sendable {
    private let routes: [Route]
    private let middlewares: [AnyMiddleware]

    init(routes: [Route], middlewares: [AnyMiddleware] = []) {
        self.routes = routes
        self.middlewares = middlewares
    }

    public func middleware<M: Middleware>(_ middleware: M) -> Routes {
        var middlewares = self.middlewares
        middlewares.append(AnyMiddleware(middleware))
        return Routes(routes: routes, middlewares: middlewares)
    }

    func resolvedRoutes() -> [Route] {
        routes.map { $0.addingGroupMiddlewares(middlewares) }
    }
}

public func Get<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .get, path: path, handler: handler)
}

public func Get<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .get, path: path, handler: handler)
}

public func Post<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .post, path: path, handler: handler)
}

public func Post<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .post, path: path, handler: handler)
}

public func Put<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .put, path: path, handler: handler)
}

public func Put<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .put, path: path, handler: handler)
}

public func Patch<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .patch, path: path, handler: handler)
}

public func Patch<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .patch, path: path, handler: handler)
}

public func Delete<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .delete, path: path, handler: handler)
}

public func Delete<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .delete, path: path, handler: handler)
}

public func Head<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .head, path: path, handler: handler)
}

public func Head<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .head, path: path, handler: handler)
}

public func Options<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable () async throws -> R
) -> Route {
    Route(method: .options, path: path, handler: handler)
}

public func Options<R: ResponseConvertible>(
    _ path: String,
    _ handler: @escaping @Sendable (Request) async throws -> R
) -> Route {
    Route(method: .options, path: path, handler: handler)
}

public func Group(_ prefix: String, @RouteBuilder routes: () -> [Route]) -> Routes {
    Routes(routes: routes().map { $0.prefixed(with: prefix) })
}

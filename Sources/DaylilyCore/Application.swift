public struct Application: Sendable {
    private let router: Router
    private let middlewares: [AnyMiddleware]

    public init(@RouteBuilder routes: () -> [Route]) {
        self.init(routes: routes())
    }

    public init(routes: [Route]) {
        self.router = Router(routes: routes)
        self.middlewares = []
    }

    public init(routes: Routes) {
        self.init(routes: routes.resolvedRoutes())
    }

    private init(router: Router, middlewares: [AnyMiddleware]) {
        self.router = router
        self.middlewares = middlewares
    }

    public func middleware<M: Middleware>(_ middleware: M) -> Application {
        var middlewares = self.middlewares
        middlewares.append(AnyMiddleware(middleware))
        return Application(router: router, middlewares: middlewares)
    }

    public func respond(to request: Request) async -> Response {
        let terminal = Handler { request in
            await Self.render {
                try await router.respond(to: request)
            }
        }
        let pipeline = middlewarePipeline(middlewares: middlewares, terminal: terminal)

        return await Self.render {
            try await pipeline.respond(to: request)
        }
    }

    private static func render(_ operation: @Sendable () async throws -> Response) async -> Response {
        do {
            return try await operation()
        } catch let error as ResponseError {
            return Response.text(error.reason, status: error.status)
        } catch {
            return Response.text("Internal Server Error", status: .internalServerError)
        }
    }
}

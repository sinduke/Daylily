public struct Application: Sendable {
    private let router: Router

    public init(@RouteBuilder routes: () -> [Route]) {
        self.router = Router(routes: routes())
    }

    public init(routes: [Route]) {
        self.router = Router(routes: routes)
    }

    public func respond(to request: Request) async -> Response {
        do {
            return try await router.respond(to: request)
        } catch let error as ResponseError {
            return Response.text(error.reason, status: error.status)
        } catch {
            return Response.text("Internal Server Error", status: .internalServerError)
        }
    }
}

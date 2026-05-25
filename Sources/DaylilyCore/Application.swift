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
        } catch let abort as Abort {
            return Response.text(abort.reason, status: abort.status)
        } catch {
            return Response.text("Internal Server Error", status: .internalServerError)
        }
    }
}

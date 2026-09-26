import DaylilyCore
public actor AuditTrail {
    private var count=0
    public init() {}
    public func record() { count += 1 }
    public func recorded() -> Int { count }
}
public struct Audit: Middleware {
    public let trail: AuditTrail
    public init(trail: AuditTrail) { self.trail=trail }
    public func handle(_ request: Request, next: Handler) async throws -> Response {
        let bytes=try await request.body.collect(upTo: .bytes(256))
        if !bytes.isEmpty { await trail.record() }
        return try await next.respond(to: request)
    }
}

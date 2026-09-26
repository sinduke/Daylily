import AppCore
import Daylily
import Foundation

public func emitCommerceEvent(_ message: String) {
    FileHandle.standardOutput.write(Data((message + "\n").utf8))
}

public actor CommerceMetrics: ResponseTransferObserver {
    private let instance: String
    private var activeRequests = 0
    private var activeStreams = 0
    private var completedRequests = 0
    private var completed = 0
    private var cancelled = 0
    private var failed = 0

    public init(instance: String) { self.instance = instance }
    func beginRequest() { activeRequests += 1 }
    func endRequest() { activeRequests -= 1; completedRequests += 1 }
    func beginStream() { activeStreams += 1 }
    func endStream() { activeStreams -= 1 }
    public func record(_ event: ResponseTransferEvent) {
        switch event.outcome {
        case .completed: completed += 1
        case .cancelled: cancelled += 1
        case .failed: failed += 1
        }
    }
    public func snapshot() -> CommerceMetricsSnapshot {
        CommerceMetricsSnapshot(instance: instance, activeRequests: activeRequests, activeStreams: activeStreams,
                                completedRequests: completedRequests, completed: completed, cancelled: cancelled, failed: failed)
    }
}

public struct CommerceMetricsSnapshot: Codable, Sendable {
    public let instance: String
    public let activeRequests: Int
    public let activeStreams: Int
    public let completedRequests: Int
    public let completed: Int
    public let cancelled: Int
    public let failed: Int
}

private struct MetricsMiddleware: Middleware {
    let metrics: CommerceMetrics
    func handle(_ request: Request, next: Handler) async throws -> Response {
        await metrics.beginRequest()
        do {
            let response = try await next.respond(to: request)
            await metrics.endRequest()
            return response
        } catch {
            await metrics.endRequest()
            throw error
        }
    }
}

private struct Availability: Encodable, Sendable {
    let status: String
    let service = "persistent-commerce"
    let instance: String
}

private func database<Value>(_ operation: () async throws -> Value) async throws -> Value {
    do { return try await operation() }
    catch let error as Abort { throw error }
    catch is CancellationError { throw CancellationError() }
    catch {
        // Database diagnostics never put SQL, credentials or customer details in HTTP output.
        throw Abort(Status(503, reasonPhrase: "Service Unavailable"), reason: "Database temporarily unavailable")
    }
}

public func makePersistentApplication(
    repository: PostgresCommerceRepository,
    metrics: CommerceMetrics,
    instance: String
) -> Application {
    Application(dependencies: { $0.register(repository) }) {
        Get("/api/health") { JSON(Availability(status: "ok", instance: instance)) }
        Get("/api/ready") { request in
            let repository = try request.dependencies.require(PostgresCommerceRepository.self)
            try await database { try await repository.checkReady() }
            return JSON(Availability(status: "ready", instance: instance))
        }
        Get("/api/metrics") { JSON(await metrics.snapshot()) }
        Get("/api/products") { request in
            let repository = try request.dependencies.require(PostgresCommerceRepository.self)
            let products = try await database { try await repository.products(category: request.query["category"]) }
            return JSON(ProductListResponse(products: products))
        }
        Get("/api/products/:id") { request in
            let id = try request.parameters.require("id", as: Int.self)
            let repository = try request.dependencies.require(PostgresCommerceRepository.self)
            guard let product = try await database({ try await repository.product(id: id) }) else {
                throw Abort(.notFound, reason: "Product not found")
            }
            return JSON(product)
        }
        Post("/api/orders") { request in
            let input = try await request.json(CreateOrderRequest.self, upTo: .kilobytes(32))
            let repository = try request.dependencies.require(PostgresCommerceRepository.self)
            let order = try await database {
                try await repository.createOrder(input, idempotencyKey: request.headers["idempotency-key"])
            }
            return JSON(order, status: .created)
        }
        Get("/api/orders/:id") { request in
            let id = try request.parameters.require("id", as: Int.self)
            let repository = try request.dependencies.require(PostgresCommerceRepository.self)
            guard let order = try await database({ try await repository.order(id: id) }) else {
                throw Abort(.notFound, reason: "Order not found")
            }
            return JSON(order)
        }
        // This bounded progress stream is an operational exercise, not a durable order feed.
        Get("/api/events") { request in
            let count = try request.query.get("count", as: Int.self) ?? 10
            let delay = try request.query.get("delay_ms", as: Int.self) ?? 100
            guard (1...10_000).contains(count), (10...2_000).contains(delay) else { throw Abort(.badRequest) }
            return Response.eventStream { writer in
                await metrics.beginStream()
                do {
                    for index in 1...count {
                        try await writer.write(ServerSentEvent(data: "\(instance):\(index)", id: String(index), event: "progress"))
                        if index < count { try await Task.sleep(for: .milliseconds(delay)) }
                    }
                    await metrics.endStream()
                } catch {
                    await metrics.endStream()
                    throw error
                }
            }
        }
    }
    .middleware(MetricsMiddleware(metrics: metrics))
    .boot { try await repository.migrate() }
    .started { emitCommerceEvent("LIFECYCLE instance=\(instance) started") }
    .shutdown { emitCommerceEvent("LIFECYCLE instance=\(instance) shutdown") }
    .cleanup { emitCommerceEvent("LIFECYCLE instance=\(instance) cleanup") }
}

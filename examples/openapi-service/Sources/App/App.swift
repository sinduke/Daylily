import DaylilyCore
import DaylilyObservability
import DaylilyOpenAPITransport
import DaylilyServiceLifecycle
import DaylilySwiftLog
import Foundation
import GeneratedAPI
import Logging
import OpenAPIURLSession
import ServiceLifecycle

struct Handler: APIProtocol {
    func getGreeting(_ input: Operations.getGreeting.Input) async throws -> Operations.getGreeting.Output {
        .ok(.init(body: .json(.init(labels: [.swift, .daylily], message: "Hello, \(input.path.name)!"))))
    }

    func echo(_ input: Operations.echo.Input) async throws -> Operations.echo.Output {
        let value: Components.Schemas.EchoInput
        switch input.body { case .json(let body): value = body }
        return .ok(.init(body: .json(.init(labels: [.daylily], message: value.message))))
    }
}

private struct VerifyHTTP: Service {
    let ready: AsyncStream<Void>
    let baseURL: URL
    let logger: Logger

    func run() async throws {
        var iterator = ready.makeAsyncIterator()
        guard await iterator.next() != nil else { throw CancellationError() }
        let client = Client(serverURL: baseURL, transport: URLSessionTransport())
        let greeting = try await client.getGreeting(path: .init(name: "Swift"))
        guard try greeting.ok.body.json.message == "Hello, Swift!" else { throw CheckError.unexpectedResponse }
        let echoed = try await client.echo(body: .json(.init(message: "generated client → Daylily")))
        let value = try echoed.ok.body.json
        guard value.message == "generated client → Daylily", value.labels == [.daylily] else {
            throw CheckError.unexpectedResponse
        }
        logger.info("OpenAPI generated server/client HTTP round trip passed")
    }
}

private actor LifecycleRecord {
    private var events: [String] = []
    func record(_ event: String) { events.append(event) }
    func isComplete() -> Bool { events == ["started", "shutdown", "cleanup"] }
}

private enum CheckError: Error { case unexpectedResponse, invalidPort, incompleteShutdown }

@main struct App {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["OPENAPI_PORT"] ?? "18083") ?? 0
        guard (1...65535).contains(port) else { throw CheckError.invalidPort }
        let logger = Logger(label: "example.openapi")
        let lifecycle = LifecycleRecord()
        let transport = DaylilyOpenAPITransport()
        try Handler().registerHandlers(on: transport, serverURL: URL(string: "/api")!)
        let (ready, continuation) = AsyncStream.makeStream(of: Void.self)
        defer { continuation.finish() }
        let app = transport.application()
            .middleware(RequestIDMiddleware())
            .middleware(RequestLoggingMiddleware(sink: SwiftLogRequestLogSink(logger: logger)))
            .started {
                await lifecycle.record("started")
                logger.info("Listening", metadata: ["port": "\(port)"])
                continuation.yield()
            }
            .shutdown {
                await lifecycle.record("shutdown")
                logger.info("HTTP service stopped")
            }
            .cleanup { await lifecycle.record("cleanup") }
        var services: [ServiceGroupConfiguration.ServiceConfiguration] = [
            .init(service: app.serviceLifecycleService(configuration: .init(
                host: "127.0.0.1", port: port, gracefulShutdownSignals: false
            ))),
        ]
        if CommandLine.arguments.contains("--check") {
            services.append(.init(
                service: VerifyHTTP(ready: ready, baseURL: URL(string: "http://127.0.0.1:\(port)/api")!, logger: logger),
                successTerminationBehavior: .gracefullyShutdownGroup
            ))
        }
        let group = ServiceGroup(configuration: .init(
            services: services,
            gracefulShutdownSignals: [.sigint, .sigterm],
            logger: logger
        ))
        try await group.run()
        if CommandLine.arguments.contains("--check") {
            guard await lifecycle.isComplete() else { throw CheckError.incompleteShutdown }
            logger.info("Application lifecycle completed once in the expected order")
        }
    }
}

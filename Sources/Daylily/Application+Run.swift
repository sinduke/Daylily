@_spi(Lifecycle) import DaylilyCore
import DaylilyNIO

extension Application {
    public func run(
        host: String = "127.0.0.1", port: Int = 8080,
        responseObserver: (any ResponseTransferObserver)? = nil
    ) async throws {
        try await run(configuration: ServerConfiguration(host: host, port: port), responseObserver: responseObserver)
    }

    public func run(
        configuration: ServerConfiguration,
        responseObserver: (any ResponseTransferObserver)? = nil
    ) async throws {
        let server = NIOHTTPServer(configuration: .init(configuration), responseObserver: responseObserver) { request in
            await respond(to: request)
        }

        try await runWithLifecycle { started in
            try await server.run(started: started)
        }
    }
}

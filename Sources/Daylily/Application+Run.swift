@_spi(Lifecycle) import DaylilyCore
import DaylilyNIO

extension Application {
    public func run(host: String = "127.0.0.1", port: Int = 8080) async throws {
        try await run(configuration: ServerConfiguration(host: host, port: port))
    }

    public func run(configuration: ServerConfiguration) async throws {
        let server = NIOHTTPServer(configuration: .init(configuration)) { request in
            await respond(to: request)
        }

        try await runWithLifecycle { started in
            try await server.run(started: started)
        }
    }
}

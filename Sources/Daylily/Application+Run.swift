import DaylilyCore
import DaylilyNIO

extension Application {
    public func run(host: String = "127.0.0.1", port: Int = 8080) async throws {
        let server = NIOHTTPServer(configuration: .init(host: host, port: port)) { request in
            await respond(to: request)
        }

        try await server.run()
    }
}

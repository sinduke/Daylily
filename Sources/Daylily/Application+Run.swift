import DaylilyCore
import DaylilyNIO

extension Application {
    public func run(host: String = "127.0.0.1", port: Int = 8080) async throws {
        try await run(configuration: ServerConfiguration(host: host, port: port))
    }

    public func run(configuration: ServerConfiguration) async throws {
        let server = NIOHTTPServer(configuration: .init(configuration)) { request in
            await respond(to: request)
        }

        try await runLifecycle(.configure)
        try await runLifecycle(.boot)

        var didShutdown = false

        do {
            try await server.run {
                try await runLifecycle(.started)
            }
            try await runLifecycle(.shutdown)
            didShutdown = true
            try await runLifecycle(.cleanup)
        } catch {
            if !didShutdown {
                try? await runLifecycle(.shutdown)
            }

            try? await runLifecycle(.cleanup)
            throw error
        }
    }
}

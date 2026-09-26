@_spi(Lifecycle) import DaylilyCore
@_spi(ServiceLifecycle) import DaylilyNIO
import ServiceLifecycle

public struct DaylilyApplicationService: Service {
    private let application: Application
    private let configuration: ServerConfiguration
    private let responseObserver: (any ResponseTransferObserver)?

    public init(
        application: Application,
        configuration: ServerConfiguration = .serviceLifecycleDefault,
        responseObserver: (any ResponseTransferObserver)? = nil
    ) {
        self.application = application
        self.configuration = configuration
        self.responseObserver = responseObserver
    }

    public func run() async throws {
        let (shutdownRequests, continuation) = AsyncStream.makeStream(of: Void.self)
        defer {
            continuation.finish()
        }

        try await withGracefulShutdownHandler {
            try await runApplication(shutdownRequests: shutdownRequests)
        } onGracefulShutdown: {
            continuation.yield()
            continuation.finish()
        }
    }

    private func runApplication(shutdownRequests: AsyncStream<Void>) async throws {
        let application = application
        let server = NIOHTTPServer(configuration: .init(configuration), responseObserver: responseObserver) { request in
            await application.respond(to: request)
        }

        try await application.runWithLifecycle { started in
            try await server.run(
                started: started,
                shutdownRequests: shutdownRequests
            )
        }
    }
}

public extension Application {
    func serviceLifecycleService(
        configuration: ServerConfiguration = .serviceLifecycleDefault,
        responseObserver: (any ResponseTransferObserver)? = nil
    ) -> DaylilyApplicationService {
        DaylilyApplicationService(application: self, configuration: configuration, responseObserver: responseObserver)
    }
}

public extension ServerConfiguration {
    static var serviceLifecycleDefault: ServerConfiguration {
        ServerConfiguration(gracefulShutdownSignals: false)
    }

    func withGracefulShutdownSignals(_ enabled: Bool) -> ServerConfiguration {
        var configuration = self
        configuration.gracefulShutdownSignals = enabled
        return configuration
    }
}

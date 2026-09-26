import Daylily
import DaylilyServiceLifecycle
import Foundation
import Logging
import PersistentCommerceCore
import PostgresNIO
import ServiceLifecycle

@main
struct PersistentCommerce {
    static func main() async {
        do { try await run() }
        catch {
            // A top-level database error can contain connection/query metadata.
            emitCommerceEvent("LIFECYCLE failed: invalid configuration, unavailable database, or service failure")
            exit(1)
        }
    }

    private static func run() async throws {
        let configuration = try CommerceConfiguration()
        let client = PostgresClient(configuration: configuration.database)
        let repository = PostgresCommerceRepository(client: client, timeout: configuration.operationTimeout)
        let metrics = CommerceMetrics(instance: configuration.instance)
        let application = makePersistentApplication(repository: repository, metrics: metrics, instance: configuration.instance)
        let http = application.serviceLifecycleService(
            configuration: ServerConfiguration(
                host: configuration.host, port: configuration.port, gracefulShutdownSignals: false,
                requestHeaderTimeout: .seconds(5), uploadIdleTimeout: .seconds(5),
                shutdownGracePeriod: configuration.shutdownGrace
            ), responseObserver: metrics
        )
        // ServiceGroup stops in reverse order: HTTP drains while the pool stays alive.
        // Startup failure or cancellation also joins both services; no detached pool task.
        let group = ServiceGroup(services: [client, http], gracefulShutdownSignals: [.sigterm, .sigint],
                                 logger: Logger(label: "commerce.lifecycle"))
        defer { emitCommerceEvent("LIFECYCLE instance=\(configuration.instance) pool_closed") }
        try await group.run()
    }
}

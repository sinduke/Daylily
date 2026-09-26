import Foundation
import PostgresNIO

public struct CommerceConfiguration: Sendable {
    public let database: PostgresClient.Configuration
    public let host: String
    public let port: Int
    public let instance: String
    public let operationTimeout: Duration
    public let shutdownGrace: Duration

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        func integer(_ name: String, _ fallback: Int, _ range: ClosedRange<Int>) throws -> Int {
            guard let value = Int(environment[name] ?? String(fallback)), range.contains(value) else {
                throw ConfigurationError.invalid(name)
            }
            return value
        }
        let tls: PostgresClient.Configuration.TLS
        switch environment["PGSSLMODE"] ?? "verify-full" {
        case "disable": tls = .disable
        case "verify-full": tls = .require(.makeClientConfiguration())
        default: throw ConfigurationError.invalid("PGSSLMODE (disable or verify-full)")
        }
        var database = PostgresClient.Configuration(
            host: environment["PGHOST"] ?? "127.0.0.1",
            port: try integer("PGPORT", 5432, 1...65_535),
            username: environment["PGUSER"] ?? "commerce",
            password: environment["PGPASSWORD"],
            database: environment["PGDATABASE"] ?? "commerce", tls: tls
        )
        database.options.maximumConnections = try integer("PGPOOL_MAX_CONNECTIONS", 8, 1...64)
        database.options.minimumConnections = 0
        database.options.connectTimeout = .seconds(2)
        database.options.additionalStartupParameters = [
            ("application_name", "daylily-commerce"),
            ("statement_timeout", "3000"),
            ("lock_timeout", "2000"),
            ("idle_in_transaction_session_timeout", "5000"),
        ]
        self.database = database
        self.host = environment["HOST"] ?? "127.0.0.1"
        self.port = try integer("PORT", 8080, 1...65_535)
        self.instance = environment["INSTANCE_ID"] ?? "local"
        self.operationTimeout = .milliseconds(try integer("DB_OPERATION_TIMEOUT_MS", 4_000, 100...30_000))
        self.shutdownGrace = .milliseconds(try integer("SHUTDOWN_GRACE_MS", 5_000, 0...60_000))
    }
}

public enum ConfigurationError: Error, CustomStringConvertible {
    case invalid(String)
    public var description: String {
        switch self { case .invalid(let field): "Invalid configuration: \(field)" }
    }
}

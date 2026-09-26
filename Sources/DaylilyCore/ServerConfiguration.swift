public struct ServerConfiguration: Equatable, Sendable {
    public var host: String
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var maxMessagesPerRead: Int
    public var gracefulShutdownSignals: Bool
    public var requestHeaderTimeout: Duration?
    public var uploadIdleTimeout: Duration?
    public var shutdownGracePeriod: Duration?

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true,
        requestHeaderTimeout: Duration? = .seconds(15),
        uploadIdleTimeout: Duration? = .seconds(30),
        shutdownGracePeriod: Duration? = .seconds(10)
    ) {
        self.host = host
        self.port = port
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.maxMessagesPerRead = maxMessagesPerRead
        self.gracefulShutdownSignals = gracefulShutdownSignals
        precondition(requestHeaderTimeout.map { $0 > .zero } ?? true, "Request header timeout must be positive")
        precondition(uploadIdleTimeout.map { $0 > .zero } ?? true, "Upload idle timeout must be positive")
        precondition(shutdownGracePeriod.map { $0 >= .zero } ?? true, "Shutdown grace period cannot be negative")
        self.requestHeaderTimeout = requestHeaderTimeout
        self.uploadIdleTimeout = uploadIdleTimeout
        self.shutdownGracePeriod = shutdownGracePeriod
    }
}

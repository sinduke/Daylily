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
    /// Maximum wait for each response write/flush; nil disables the deadline.
    /// Time spent in the handler or waiting between producer writes is excluded.
    public var responseWriteTimeout: Duration?
    /// Maximum concurrent observation deliveries across all server connections.
    /// New events are dropped immediately while every delivery slot is occupied.
    public var responseObserverCapacity: Int

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true,
        requestHeaderTimeout: Duration? = .seconds(15),
        uploadIdleTimeout: Duration? = .seconds(30),
        shutdownGracePeriod: Duration? = .seconds(10),
        responseWriteTimeout: Duration? = .seconds(30),
        responseObserverCapacity: Int = 64
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
        precondition(responseWriteTimeout.map { $0 > .zero } ?? true, "Response write timeout must be positive")
        precondition(responseObserverCapacity > 0, "Response observer capacity must be positive")
        self.responseWriteTimeout = responseWriteTimeout
        self.responseObserverCapacity = responseObserverCapacity
    }
}

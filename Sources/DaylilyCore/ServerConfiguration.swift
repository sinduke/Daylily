public struct ServerConfiguration: Equatable, Sendable {
    public var host: String
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var maxMessagesPerRead: Int
    public var gracefulShutdownSignals: Bool

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true
    ) {
        self.host = host
        self.port = port
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.maxMessagesPerRead = maxMessagesPerRead
        self.gracefulShutdownSignals = gracefulShutdownSignals
    }
}

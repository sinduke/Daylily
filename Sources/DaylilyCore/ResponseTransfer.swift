/// The terminal transport outcome, independent of the HTTP response status.
public enum ResponseTransferOutcome: String, Equatable, Sendable {
    case completed
    case cancelled
    case failed
}

/// One immutable terminal response-transfer observation.
///
/// `bytesSent` counts body bytes whose transport write/flush completed successfully.
/// It excludes headers/framing and does not prove that the peer consumed those bytes.
/// `durationNanoseconds` runs from the beginning of response transmission to its
/// terminal state. It does not include the route handler's response-production time
/// or the observer's delivery time.
public struct ResponseTransferEvent: Equatable, Sendable {
    public let method: HTTPMethod?
    public let path: String?
    public let status: Status
    public let requestID: String?
    public let correlationID: String?
    public let bytesSent: Int
    public let durationNanoseconds: UInt64
    public let outcome: ResponseTransferOutcome

    public init(
        method: HTTPMethod? = nil,
        path: String? = nil,
        status: Status,
        requestID: String? = nil,
        correlationID: String? = nil,
        bytesSent: Int,
        durationNanoseconds: UInt64,
        outcome: ResponseTransferOutcome
    ) {
        self.method = method
        self.path = path
        self.status = status
        self.requestID = requestID
        self.correlationID = correlationID
        self.bytesSent = bytesSent
        self.durationNanoseconds = durationNanoseconds
        self.outcome = outcome
    }
}

/// Receives response-transfer terminal events without changing HTTP behavior.
///
/// The transport arbitrates terminal state exactly once for each observed response,
/// then delivers the event asynchronously outside its event loop. Different responses
/// may invoke this method concurrently and in a different order from their requests.
/// Server shutdown does not wait indefinitely for observers: delivery is best effort
/// if the process exits. Applications own durable buffering or exporter shutdown.
/// No observation task is created when no observer is configured.
public protocol ResponseTransferObserver: Sendable {
    func record(_ event: ResponseTransferEvent) async
}

import DaylilyCore

/// A collector intended for tests and local inspection; retains events until released.
public actor InMemoryResponseTransferObserver: ResponseTransferObserver {
    private var events: [ResponseTransferEvent] = []

    public init() {}

    public func record(_ event: ResponseTransferEvent) {
        events.append(event)
    }

    public func snapshot() -> [ResponseTransferEvent] {
        events
    }
}

/// Prints terminal transfer information separately from handler request logs.
public struct ConsoleResponseTransferObserver: ResponseTransferObserver {
    public init() {}

    public func record(_ event: ResponseTransferEvent) async {
        var fields = [
            "outcome=\(event.outcome.rawValue)",
            "status=\(event.status.code)",
            "bodyBytesSent=\(event.bytesSent)",
            "transferDurationNs=\(event.durationNanoseconds)",
        ]
        if let method = event.method { fields.append("method=\(method.rawValue)") }
        if let path = event.path { fields.append("path=\(path)") }
        if let requestID = event.requestID { fields.append("requestID=\(requestID)") }
        if let correlationID = event.correlationID { fields.append("correlationID=\(correlationID)") }
        print("response.transfer " + fields.joined(separator: " "))
    }
}

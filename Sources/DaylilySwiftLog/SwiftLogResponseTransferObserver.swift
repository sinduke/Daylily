import DaylilyCore
import Logging

/// An optional SwiftLog adapter; applications retain logger/bootstrap ownership.
public struct SwiftLogResponseTransferObserver: ResponseTransferObserver {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    public init(label: String = "daylily.response.transfer") {
        self.init(logger: Logger(label: label))
    }

    public func record(_ event: ResponseTransferEvent) async {
        let level: Logger.Level
        switch event.outcome {
        case .completed: level = .info
        case .cancelled: level = .notice
        case .failed: level = .error
        }
        var metadata: Logger.Metadata = [
            "daylily.event": "response_transfer",
            "daylily.http.status_code": "\(event.status.code)",
            "daylily.response.outcome": "\(event.outcome.rawValue)",
            "daylily.response.bytes_sent": "\(event.bytesSent)",
            "daylily.response.transfer_duration_ns": "\(event.durationNanoseconds)",
        ]
        if let method = event.method { metadata["daylily.http.method"] = "\(method.rawValue)" }
        if let path = event.path { metadata["daylily.http.path"] = "\(path)" }
        if let requestID = event.requestID, !requestID.isEmpty {
            metadata["daylily.request_id"] = "\(requestID)"
        }
        if let correlationID = event.correlationID, !correlationID.isEmpty {
            metadata["daylily.correlation_id"] = "\(correlationID)"
        }
        logger.log(level: level, "Response transfer \(event.outcome.rawValue)", metadata: metadata)
    }
}

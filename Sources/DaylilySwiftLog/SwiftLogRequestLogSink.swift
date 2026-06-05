import DaylilyObservability
import Logging

public struct SwiftLogRequestLogSink: RequestLogSink {
    private let logger: Logger
    private let levelStrategy: SwiftLogRequestLogLevelStrategy
    private let metadataStrategy: SwiftLogRequestLogMetadataStrategy

    public init(
        logger: Logger,
        level: SwiftLogRequestLogLevelStrategy = .statusBased,
        metadata: SwiftLogRequestLogMetadataStrategy = .default
    ) {
        self.logger = logger
        self.levelStrategy = level
        self.metadataStrategy = metadata
    }

    public init(
        label: String = "daylily.request",
        level: SwiftLogRequestLogLevelStrategy = .statusBased,
        metadata: SwiftLogRequestLogMetadataStrategy = .default
    ) {
        self.init(
            logger: Logger(label: label),
            level: level,
            metadata: metadata
        )
    }

    public func record(_ log: RequestLog) async {
        logger.log(
            level: levelStrategy.level(for: log),
            "\(log.method.rawValue) \(log.path) -> \(log.status.code)",
            metadata: metadataStrategy.metadata(for: log)
        )
    }
}

public struct SwiftLogRequestLogLevelStrategy: Sendable {
    private let selectLevel: @Sendable (RequestLog) -> Logger.Level

    public init(_ selectLevel: @escaping @Sendable (RequestLog) -> Logger.Level) {
        self.selectLevel = selectLevel
    }

    public static let statusBased = Self { log in
        switch log.status.code {
        case 100..<400:
            return .info
        case 400..<500:
            return .warning
        default:
            return .error
        }
    }

    public static func constant(_ level: Logger.Level) -> Self {
        Self { _ in level }
    }

    public func level(for log: RequestLog) -> Logger.Level {
        selectLevel(log)
    }
}

public struct SwiftLogRequestLogMetadataStrategy: Sendable {
    private let makeMetadata: @Sendable (RequestLog) -> Logger.Metadata

    public init(_ makeMetadata: @escaping @Sendable (RequestLog) -> Logger.Metadata) {
        self.makeMetadata = makeMetadata
    }

    public static let `default` = Self { log in
        var metadata: Logger.Metadata = [
            "daylily.http.method": "\(log.method.rawValue)",
            "daylily.http.path": "\(log.path)",
            "daylily.http.status_code": "\(log.status.code)",
        ]

        if let requestID = log.requestID, !requestID.isEmpty {
            metadata["daylily.request_id"] = "\(requestID)"
        }

        if let correlationID = log.correlationID, !correlationID.isEmpty {
            metadata["daylily.correlation_id"] = "\(correlationID)"
        }

        if let durationNanoseconds = log.durationNanoseconds {
            metadata["daylily.duration_ns"] = "\(durationNanoseconds)"
        }

        if let errorReason = log.errorReason, !errorReason.isEmpty {
            metadata["daylily.error.reason"] = "\(errorReason)"
        }

        return metadata
    }

    public func metadata(for log: RequestLog) -> Logger.Metadata {
        makeMetadata(log)
    }
}

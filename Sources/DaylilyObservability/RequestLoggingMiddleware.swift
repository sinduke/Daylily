import DaylilyCore
import Dispatch

public struct RequestLog: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var status: Status
    public var requestID: String?
    public var correlationID: String?
    public var durationNanoseconds: UInt64?
    public var errorReason: String?

    public init(
        method: HTTPMethod,
        path: String,
        status: Status,
        requestID: String? = nil,
        correlationID: String? = nil,
        durationNanoseconds: UInt64? = nil,
        errorReason: String? = nil
    ) {
        self.method = method
        self.path = path
        self.status = status
        self.requestID = requestID
        self.correlationID = correlationID
        self.durationNanoseconds = durationNanoseconds
        self.errorReason = errorReason
    }
}

public protocol RequestLogSink: Sendable {
    func record(_ log: RequestLog) async
}

public struct RequestLoggingMiddleware<Sink: RequestLogSink>: Middleware {
    private let sink: Sink

    public init(sink: Sink) {
        self.sink = sink
    }

    public func handle(_ request: Request, next: Handler) async throws -> Response {
        let start = DispatchTime.now().uptimeNanoseconds

        do {
            let response = try await next.respond(to: request)
            await sink.record(log(for: request, response: response, startedAt: start))
            return response
        } catch let error as ResponseError {
            await sink.record(log(for: request, status: error.status, startedAt: start))
            throw error
        } catch {
            await sink.record(log(for: request, status: .internalServerError, startedAt: start))
            throw error
        }
    }

    private func log(for request: Request, response: Response, startedAt start: UInt64) -> RequestLog {
        let requestID = response.headers[RequestIDHeaders.daylilyRequestID] ?? request.daylilyRequestID
        let responseCorrelationID = response.headers[RequestIDHeaders.requestID]
        let correlationID = Self.externalCorrelationID(
            requestID: requestID,
            requestCorrelationID: request.correlationID,
            responseCorrelationID: responseCorrelationID
        )

        return RequestLog(
            method: request.method,
            path: request.path,
            status: response.status,
            requestID: requestID,
            correlationID: correlationID,
            durationNanoseconds: Self.elapsedNanoseconds(since: start),
            errorReason: Self.errorReason(for: response)
        )
    }

    private func log(for request: Request, status: Status, startedAt start: UInt64) -> RequestLog {
        RequestLog(
            method: request.method,
            path: request.path,
            status: status,
            requestID: request.daylilyRequestID,
            correlationID: Self.externalCorrelationID(
                requestID: request.daylilyRequestID,
                requestCorrelationID: request.correlationID,
                responseCorrelationID: nil
            ),
            durationNanoseconds: Self.elapsedNanoseconds(since: start),
            errorReason: status.reasonPhrase
        )
    }

    private static func elapsedNanoseconds(since start: UInt64) -> UInt64 {
        DispatchTime.now().uptimeNanoseconds - start
    }

    private static func errorReason(for response: Response) -> String? {
        guard response.status.code >= 400 else {
            return nil
        }

        return response.bodyString.isEmpty ? response.status.reasonPhrase : response.bodyString
    }

    private static func externalCorrelationID(
        requestID: String?,
        requestCorrelationID: String?,
        responseCorrelationID: String?
    ) -> String? {
        let value = requestCorrelationID ?? responseCorrelationID
        guard value != requestID else {
            return nil
        }

        return value
    }
}

public struct ConsoleRequestLogSink: RequestLogSink {
    public init() {}

    public func record(_ log: RequestLog) async {
        var fields: [String] = []

        if let requestID = log.requestID {
            fields.append("requestID=\(requestID)")
        }

        if let correlationID = log.correlationID {
            fields.append("correlationID=\(correlationID)")
        }

        if let durationNanoseconds = log.durationNanoseconds {
            fields.append("duration=\(Self.formatDuration(durationNanoseconds))")
        }

        if let errorReason = log.errorReason {
            fields.append("error=\(errorReason)")
        }

        let suffix = fields.isEmpty ? "" : " " + fields.joined(separator: " ")
        print("\(log.method.rawValue) \(log.path) -> \(log.status.code)\(suffix)")
    }

    private static func formatDuration(_ nanoseconds: UInt64) -> String {
        let milliseconds = Double(nanoseconds) / 1_000_000
        return "\(milliseconds)ms"
    }
}

public actor InMemoryRequestLogSink: RequestLogSink {
    private var logs: [RequestLog] = []

    public init() {}

    public func record(_ log: RequestLog) {
        logs.append(log)
    }

    public func snapshot() -> [RequestLog] {
        logs
    }
}

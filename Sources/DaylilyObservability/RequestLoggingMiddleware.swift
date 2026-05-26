import DaylilyCore

public struct RequestLog: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var status: Status

    public init(method: HTTPMethod, path: String, status: Status) {
        self.method = method
        self.path = path
        self.status = status
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
        do {
            let response = try await next.respond(to: request)
            await sink.record(RequestLog(method: request.method, path: request.path, status: response.status))
            return response
        } catch let error as ResponseError {
            await sink.record(RequestLog(method: request.method, path: request.path, status: error.status))
            throw error
        } catch {
            await sink.record(RequestLog(method: request.method, path: request.path, status: .internalServerError))
            throw error
        }
    }
}

public struct ConsoleRequestLogSink: RequestLogSink {
    public init() {}

    public func record(_ log: RequestLog) async {
        print("\(log.method.rawValue) \(log.path) -> \(log.status.code)")
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

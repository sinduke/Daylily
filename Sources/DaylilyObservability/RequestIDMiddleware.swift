import DaylilyCore
import Foundation

public typealias RequestIDGenerator = @Sendable () -> String

public enum RequestIDHeaders {
    public static let requestID = "x-request-id"
    public static let daylilyRequestID = "x-daylily-request-id"
}

public enum RequestIDs {
    public static func generate() -> String {
        "dl_\(UUID().uuidString)"
    }
}

public struct RequestIDMiddleware: Middleware {
    private let generator: RequestIDGenerator

    public init(generator: @escaping RequestIDGenerator = RequestIDs.generate) {
        self.generator = generator
    }

    public func handle(_ request: Request, next: Handler) async throws -> Response {
        let requestID = generator()
        let externalCorrelationID = request.headers[RequestIDHeaders.requestID]
        let downstreamRequest = request.withRequestIDs(
            requestID: requestID,
            correlationID: externalCorrelationID
        )

        do {
            var response = try await next.respond(to: downstreamRequest)
            applyRequestIDHeaders(
                requestID: requestID,
                correlationID: externalCorrelationID,
                to: &response
            )
            return response
        } catch let error as ResponseError {
            var response = Response.text(error.reason, status: error.status)
            applyRequestIDHeaders(
                requestID: requestID,
                correlationID: externalCorrelationID,
                to: &response
            )
            return response
        } catch {
            var response = Response.text("Internal Server Error", status: .internalServerError)
            applyRequestIDHeaders(
                requestID: requestID,
                correlationID: externalCorrelationID,
                to: &response
            )
            return response
        }
    }

    private func applyRequestIDHeaders(
        requestID: String,
        correlationID: String?,
        to response: inout Response
    ) {
        response.headers[RequestIDHeaders.daylilyRequestID] = requestID
        response.headers[RequestIDHeaders.requestID] = correlationID ?? requestID
    }
}

public extension Request {
    var daylilyRequestID: String? {
        headers[RequestIDHeaders.daylilyRequestID]
    }

    var correlationID: String? {
        headers[RequestIDHeaders.requestID]
    }

    func withRequestIDs(requestID: String, correlationID: String?) -> Request {
        var headers = self.headers
        headers[RequestIDHeaders.daylilyRequestID] = requestID
        headers[RequestIDHeaders.requestID] = correlationID ?? requestID
        return with(headers: headers)
    }
}

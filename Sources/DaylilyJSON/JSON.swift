import DaylilyCore
import Foundation

public struct JSON<Value: Encodable & Sendable>: ResponseConvertible {
    public var value: Value
    public var status: Status
    public var headers: Headers

    public init(
        _ value: Value,
        status: Status = .ok,
        headers: Headers = [:]
    ) {
        self.value = value
        self.status = status
        self.headers = headers
    }

    public func toResponse() async throws -> Response {
        let data = try JSONEncoder().encode(value)
        var responseHeaders = headers
        responseHeaders["content-type"] = responseHeaders["content-type"] ?? "application/json"

        return Response(
            status: status,
            headers: responseHeaders,
            body: Array(data)
        )
    }
}

public extension Request {
    func json<Value: Decodable>(_ type: Value.Type) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: Data(body))
        } catch {
            throw Abort(.badRequest, reason: "Invalid JSON body")
        }
    }
}

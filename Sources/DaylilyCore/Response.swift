public struct Response: Sendable {
    public var status: Status
    public var headers: Headers
    public var body: [UInt8]

    public init(
        status: Status = .ok,
        headers: Headers = [:],
        body: [UInt8] = []
    ) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public static func text(
        _ value: String,
        status: Status = .ok,
        headers: Headers = [:]
    ) -> Response {
        var responseHeaders = headers
        responseHeaders["content-type"] = responseHeaders["content-type"] ?? "text/plain; charset=utf-8"
        return Response(status: status, headers: responseHeaders, body: Array(value.utf8))
    }

    public var bodyString: String {
        String(decoding: body, as: UTF8.self)
    }
}

public protocol ResponseConvertible: Sendable {
    func toResponse() async throws -> Response
}

extension Response: ResponseConvertible {
    public func toResponse() async throws -> Response {
        self
    }
}

extension Status: ResponseConvertible {
    public func toResponse() async throws -> Response {
        Response(status: self)
    }
}

extension String: ResponseConvertible {
    public func toResponse() async throws -> Response {
        Response.text(self)
    }
}

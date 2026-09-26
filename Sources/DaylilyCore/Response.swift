public struct Response: Sendable {
    public var status: Status
    public var headers: Headers
    public var responseBody: ResponseBody

    /// Buffered compatibility view. Streaming bodies must be collected explicitly.
    /// Assigning bytes replaces any existing stream.
    public var body: [UInt8] {
        get { responseBody.bufferedBytes ?? [] }
        set { responseBody = .bytes(newValue) }
    }

    public init(
        status: Status = .ok,
        headers: Headers = [:],
        body: [UInt8] = []
    ) {
        self.status = status
        self.headers = headers
        self.responseBody = .bytes(body)
    }

    public init(status: Status = .ok, headers: Headers = [:], body: ResponseBody) {
        self.status = status
        self.headers = headers
        self.responseBody = body
    }

    public static func eventStream(
        status: Status = .ok,
        headers: Headers = [:],
        _ producer: @escaping ResponseBody.Producer
    ) -> Response {
        var headers = headers
        headers["content-type"] = "text/event-stream; charset=utf-8"
        headers["cache-control"] = headers["cache-control"] ?? "no-cache"
        return Response(status: status, headers: headers, body: .stream(producer))
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

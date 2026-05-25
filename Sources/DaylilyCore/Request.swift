public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: Body
    public let parameters: Parameters

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: Body = .bytes([]),
        parameters: Parameters = Parameters()
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.parameters = parameters
    }

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8],
        parameters: Parameters = Parameters()
    ) {
        self.init(
            method: method,
            path: path,
            headers: headers,
            body: .bytes(body),
            parameters: parameters
        )
    }

    public func with(parameters: Parameters) -> Request {
        Request(
            method: method,
            path: path,
            headers: headers,
            body: body,
            parameters: parameters
        )
    }
}

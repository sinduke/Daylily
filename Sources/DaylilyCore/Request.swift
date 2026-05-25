public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: [UInt8]
    public let parameters: Parameters

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8] = [],
        parameters: Parameters = Parameters()
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.parameters = parameters
    }

    public var bodyString: String {
        String(decoding: body, as: UTF8.self)
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

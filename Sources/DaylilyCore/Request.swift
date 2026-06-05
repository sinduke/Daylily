public struct Request: Sendable {
    public let method: HTTPMethod
    public let rawTarget: String?
    public let path: String
    public let scheme: String?
    public let authority: String?
    public let extendedConnectProtocol: String?
    public let headers: Headers
    public let body: RequestBody
    public let parameters: Parameters
    public let query: QueryParameters
    public let dependencies: Dependencies

    public var target: String {
        rawTarget ?? path
    }

    public init(
        method: HTTPMethod,
        path: String,
        scheme: String? = nil,
        authority: String? = nil,
        extendedConnectProtocol: String? = nil,
        headers: Headers = [:],
        body: RequestBody = .bytes([]),
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil,
        dependencies: Dependencies = Dependencies()
    ) {
        self.init(
            method: method,
            rawTarget: path.isEmpty ? "/" : path,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public init(
        method: HTTPMethod,
        rawTarget: String?,
        scheme: String? = nil,
        authority: String? = nil,
        extendedConnectProtocol: String? = nil,
        headers: Headers = [:],
        body: RequestBody = .bytes([]),
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil,
        dependencies: Dependencies = Dependencies()
    ) {
        let parsedTarget = rawTarget.map(Self.parseTarget) ?? (path: "/", query: QueryParameters())
        self.method = method
        if let query {
            self.rawTarget = rawTarget == nil && query.queryString == nil ? nil : Self.makeTarget(path: parsedTarget.path, query: query)
        } else {
            self.rawTarget = rawTarget.map { $0.isEmpty ? "/" : $0 }
        }
        self.path = parsedTarget.path
        self.scheme = scheme
        self.authority = authority
        self.extendedConnectProtocol = extendedConnectProtocol
        self.headers = headers
        self.body = body
        self.parameters = parameters
        self.query = query ?? parsedTarget.query
        self.dependencies = dependencies
    }

    public init(
        method: HTTPMethod,
        path: String,
        scheme: String? = nil,
        authority: String? = nil,
        extendedConnectProtocol: String? = nil,
        headers: Headers = [:],
        body: [UInt8],
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil,
        dependencies: Dependencies = Dependencies()
    ) {
        self.init(
            method: method,
            path: path,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: .bytes(body),
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func with(parameters: Parameters) -> Request {
        Request(
            method: method,
            rawTarget: rawTarget,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func with(body: RequestBody) -> Request {
        Request(
            method: method,
            rawTarget: rawTarget,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func with(headers: Headers) -> Request {
        Request(
            method: method,
            rawTarget: rawTarget,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func with(dependencies: Dependencies) -> Request {
        Request(
            method: method,
            rawTarget: rawTarget,
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func with(query: QueryParameters) -> Request {
        Request(
            method: method,
            rawTarget: Self.makeTarget(path: path, query: query),
            scheme: scheme,
            authority: authority,
            extendedConnectProtocol: extendedConnectProtocol,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query,
            dependencies: dependencies
        )
    }

    public func withBufferedBody<R: Sendable>(
        upTo limit: ByteCount,
        _ operation: @Sendable (Request, [UInt8]) async throws -> R
    ) async throws -> R {
        let bytes = try await body.collect(upTo: limit)
        let replayedRequest = with(body: .bytes(bytes))
        return try await operation(replayedRequest, bytes)
    }

    private static func parseTarget(_ target: String) -> (path: String, query: QueryParameters) {
        let normalizedTarget = target.isEmpty ? "/" : target
        let parts = normalizedTarget.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let requestPath = parts.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 } ?? "/"

        guard parts.count == 2 else {
            return (requestPath, QueryParameters())
        }

        return (requestPath, QueryParameters(rawValue: String(parts[1])))
    }

    private static func makeTarget(path: String, query: QueryParameters) -> String {
        guard let queryString = query.queryString else {
            return path
        }

        return "\(path)?\(queryString)"
    }
}

public struct Request: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: Headers
    public let body: RequestBody
    public let parameters: Parameters
    public let query: QueryParameters

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([]),
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil
    ) {
        let parsedPath = Self.parsePath(path)
        self.method = method
        self.path = parsedPath.path
        self.headers = headers
        self.body = body
        self.parameters = parameters
        self.query = query ?? parsedPath.query
    }

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: [UInt8],
        parameters: Parameters = Parameters(),
        query: QueryParameters? = nil
    ) {
        self.init(
            method: method,
            path: path,
            headers: headers,
            body: .bytes(body),
            parameters: parameters,
            query: query
        )
    }

    public func with(parameters: Parameters) -> Request {
        Request(
            method: method,
            path: path,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query
        )
    }

    public func with(body: RequestBody) -> Request {
        Request(
            method: method,
            path: path,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query
        )
    }

    public func with(headers: Headers) -> Request {
        Request(
            method: method,
            path: path,
            headers: headers,
            body: body,
            parameters: parameters,
            query: query
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

    private static func parsePath(_ path: String) -> (path: String, query: QueryParameters) {
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let requestPath = parts.first.map(String.init).flatMap { $0.isEmpty ? nil : $0 } ?? "/"

        guard parts.count == 2 else {
            return (requestPath, QueryParameters())
        }

        return (requestPath, QueryParameters(parseQuery(parts[1])))
    }

    private static func parseQuery(_ query: Substring) -> [String: String] {
        var values: [String: String] = [:]

        for pair in query.split(separator: "&", omittingEmptySubsequences: false) {
            guard !pair.isEmpty else {
                continue
            }

            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = percentDecode(parts[0])
            let value = parts.count == 2 ? percentDecode(parts[1]) : ""
            values[name] = value
        }

        return values
    }

    private static func percentDecode(_ value: Substring) -> String {
        var bytes: [UInt8] = []
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]

            if character == "+" {
                bytes.append(0x20)
                index = value.index(after: index)
                continue
            }

            if character == "%",
               let first = value.index(index, offsetBy: 1, limitedBy: value.endIndex),
               first < value.endIndex,
               let second = value.index(first, offsetBy: 1, limitedBy: value.endIndex),
               second < value.endIndex,
               let byte = hexByte(value[first], value[second]) {
                bytes.append(byte)
                index = value.index(after: second)
                continue
            }

            bytes.append(contentsOf: String(character).utf8)
            index = value.index(after: index)
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    private static func hexByte(_ first: Character, _ second: Character) -> UInt8? {
        guard let high = hexValue(first), let low = hexValue(second) else {
            return nil
        }

        return high * 16 + low
    }

    private static func hexValue(_ character: Character) -> UInt8? {
        switch character {
        case "0"..."9":
            return character.asciiValue.map { $0 - Character("0").asciiValue! }
        case "a"..."f":
            return character.asciiValue.map { $0 - Character("a").asciiValue! + 10 }
        case "A"..."F":
            return character.asciiValue.map { $0 - Character("A").asciiValue! + 10 }
        default:
            return nil
        }
    }
}

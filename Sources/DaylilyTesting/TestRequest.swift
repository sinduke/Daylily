import DaylilyCore
import Foundation

public struct TestRequest: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var headers: Headers
    public var body: RequestBody

    public init(
        method: HTTPMethod,
        path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([])
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    public static func get(
        _ path: String,
        headers: Headers = [:]
    ) -> TestRequest {
        TestRequest(method: .get, path: path, headers: headers)
    }

    public static func post(
        _ path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([])
    ) -> TestRequest {
        TestRequest(method: .post, path: path, headers: headers, body: body)
    }

    public static func put(
        _ path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([])
    ) -> TestRequest {
        TestRequest(method: .put, path: path, headers: headers, body: body)
    }

    public static func patch(
        _ path: String,
        headers: Headers = [:],
        body: RequestBody = .bytes([])
    ) -> TestRequest {
        TestRequest(method: .patch, path: path, headers: headers, body: body)
    }

    public static func delete(
        _ path: String,
        headers: Headers = [:]
    ) -> TestRequest {
        TestRequest(method: .delete, path: path, headers: headers)
    }

    public static func head(
        _ path: String,
        headers: Headers = [:]
    ) -> TestRequest {
        TestRequest(method: .head, path: path, headers: headers)
    }

    public static func options(
        _ path: String,
        headers: Headers = [:]
    ) -> TestRequest {
        TestRequest(method: .options, path: path, headers: headers)
    }

    public func withHeader(_ name: String, _ value: String) -> TestRequest {
        var copy = self
        copy.headers[name] = value
        return copy
    }

    public func withBody(_ body: RequestBody) -> TestRequest {
        var copy = self
        copy.body = body
        return copy
    }

    public func withBody(_ bytes: [UInt8]) -> TestRequest {
        withBody(.bytes(bytes))
    }

    public func withBody(_ string: String) -> TestRequest {
        withBody(Array(string.utf8))
    }

    public func withJSON<Value: Encodable>(_ value: Value) throws -> TestRequest {
        var copy = withBody(Array(try JSONEncoder().encode(value)))
        copy.headers["content-type"] = copy.headers["content-type"] ?? "application/json"
        return copy
    }

    public func toRequest() -> Request {
        Request(method: method, path: path, headers: headers, body: body)
    }
}

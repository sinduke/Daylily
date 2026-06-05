@_spi(Transport) import DaylilyCore
import DaylilyHTTPTypes
import Foundation
public import HTTPTypes
public import OpenAPIRuntime

public enum DaylilyOpenAPITransportError: Error, Equatable, Sendable {
    case invalidHTTPMethod(String)
    case unsupportedPathTemplate(String)
    case duplicatePathParameter(String)
    case missingPathParameter(String)
}

public final class DaylilyOpenAPITransport: ServerTransport, @unchecked Sendable {
    private let responseBodyBufferLimit: ByteCount
    private let lock = NSLock()
    private var registeredRoutes: [Route] = []

    public init(responseBodyBufferLimit: ByteCount = .megabytes(1)) {
        self.responseBodyBufferLimit = responseBodyBufferLimit
    }

    public func register(
        _ handler: @Sendable @escaping (HTTPRequest, HTTPBody?, ServerRequestMetadata) async throws -> (
            HTTPResponse,
            HTTPBody?
        ),
        method: HTTPRequest.Method,
        path: String
    ) throws {
        guard let daylilyMethod = HTTPMethod(method.rawValue) else {
            throw DaylilyOpenAPITransportError.invalidHTTPMethod(method.rawValue)
        }

        let registeredPath = try Self.registeredPath(from: path)
        let responseBodyBufferLimit = responseBodyBufferLimit
        let route = Route(method: daylilyMethod, path: registeredPath.daylilyPath) { request in
            let httpRequest = try request.httpTypesRequest()
            let body = HTTPBody(daylilyBody: request.body, length: Self.bodyLength(from: request))
            let metadata = try Self.metadata(from: request, parameterNames: registeredPath.parameterNames)
            let (httpResponse, httpBody) = try await handler(httpRequest, body, metadata)
            let responseBody = try await Self.collectResponseBody(httpBody, upTo: responseBodyBufferLimit)
            return Response(httpTypesResponse: httpResponse, body: responseBody)
        }

        append(route)
    }

    public func routes() -> [Route] {
        lock.lock()
        defer { lock.unlock() }
        return registeredRoutes
    }

    public func application(
        dependencies configureDependencies: @Sendable (inout Dependencies) -> Void = { _ in }
    ) -> Application {
        Application(dependencies: configureDependencies) {
            routes()
        }
    }

    private func append(_ route: Route) {
        lock.lock()
        defer { lock.unlock() }
        registeredRoutes.append(route)
    }

    private static func registeredPath(from path: String) throws -> RegisteredPath {
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var convertedSegments: [String] = []
        var parameterNames: [String] = []
        var seenParameterNames = Set<String>()

        for segment in segments {
            if segment.hasPrefix("{"), segment.hasSuffix("}"), segment.dropFirst().dropLast().contains("{") == false,
               segment.dropFirst().dropLast().contains("}") == false
            {
                let name = String(segment.dropFirst().dropLast())
                guard !name.isEmpty else {
                    throw DaylilyOpenAPITransportError.unsupportedPathTemplate(path)
                }
                guard seenParameterNames.insert(name).inserted else {
                    throw DaylilyOpenAPITransportError.duplicatePathParameter(name)
                }

                parameterNames.append(name)
                convertedSegments.append(":\(name)")
            } else {
                guard !segment.contains("{"), !segment.contains("}") else {
                    throw DaylilyOpenAPITransportError.unsupportedPathTemplate(path)
                }
                convertedSegments.append(segment)
            }
        }

        return RegisteredPath(
            daylilyPath: convertedSegments.isEmpty ? "/" : "/" + convertedSegments.joined(separator: "/"),
            parameterNames: parameterNames
        )
    }

    private static func metadata(
        from request: Request,
        parameterNames: [String]
    ) throws -> ServerRequestMetadata {
        var pathParameters: [String: Substring] = [:]

        for name in parameterNames {
            guard let value = request.parameters[name] else {
                throw DaylilyOpenAPITransportError.missingPathParameter(name)
            }
            pathParameters[name] = Substring(value)
        }

        return ServerRequestMetadata(pathParameters: pathParameters)
    }

    private static func bodyLength(from request: Request) -> HTTPBody.Length {
        guard
            let contentLength = request.headers["content-length"],
            let byteCount = Int64(contentLength),
            byteCount >= 0
        else {
            return .unknown
        }

        return .known(byteCount)
    }

    private static func collectResponseBody(_ body: HTTPBody?, upTo limit: ByteCount) async throws -> [UInt8] {
        guard let body else {
            return []
        }

        return try await Array(collecting: body, upTo: limit.bytes)
    }
}

private struct RegisteredPath: Sendable {
    let daylilyPath: String
    let parameterNames: [String]
}

private struct DaylilyRequestBodySequence: AsyncSequence, Sendable {
    typealias Element = HTTPBody.ByteChunk

    private let body: RequestBody

    init(body: RequestBody) {
        self.body = body
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(iterator: body.bytes.makeAsyncIterator())
    }

    struct Iterator: AsyncIteratorProtocol {
        private var iterator: BodyBytes.AsyncIterator

        init(iterator: BodyBytes.AsyncIterator) {
            self.iterator = iterator
        }

        mutating func next() async throws -> HTTPBody.ByteChunk? {
            guard let chunk = try await iterator.next() else {
                return nil
            }

            return ArraySlice(chunk.bytes)
        }
    }
}

private extension HTTPBody {
    convenience init(daylilyBody: RequestBody, length: HTTPBody.Length) {
        self.init(
            DaylilyRequestBodySequence(body: daylilyBody),
            length: length,
            iterationBehavior: .single
        )
    }
}

import DaylilyCore
import HTTPTypes

public enum DaylilyHTTPTypesError: Error, Equatable, Sendable {
    case invalidMethod(String)
    case invalidHeaderName(String)
    case invalidHeaderValue(name: String, value: String)
    case invalidStatusCode(Int)
    case invalidReasonPhrase(String)
}

public extension Request {
    init(
        httpTypesRequest: HTTPRequest,
        body: RequestBody = .bytes([]),
        parameters: Parameters = Parameters(),
        dependencies: Dependencies = Dependencies()
    ) {
        self.init(
            method: HTTPMethod(httpTypesRequest.method.rawValue)!,
            rawTarget: httpTypesRequest.path,
            scheme: httpTypesRequest.scheme,
            authority: httpTypesRequest.authority,
            extendedConnectProtocol: httpTypesRequest.extendedConnectProtocol,
            headers: Headers(httpTypesHeaderFields: httpTypesRequest.headerFields),
            body: body,
            parameters: parameters,
            dependencies: dependencies
        )
    }

    func httpTypesRequest() throws -> HTTPRequest {
        guard let method = HTTPRequest.Method(self.method.rawValue) else {
            throw DaylilyHTTPTypesError.invalidMethod(self.method.rawValue)
        }

        var request = HTTPRequest(
            method: method,
            scheme: scheme,
            authority: authority,
            path: rawTarget,
            headerFields: try headers.httpTypesHeaderFields()
        )
        request.extendedConnectProtocol = extendedConnectProtocol
        return request
    }
}

public extension Response {
    init(httpTypesResponse: HTTPResponse, body: [UInt8] = []) {
        self.init(
            status: Status(
                httpTypesResponse.status.code,
                reasonPhrase: httpTypesResponse.status.reasonPhrase
            ),
            headers: Headers(httpTypesHeaderFields: httpTypesResponse.headerFields),
            body: body
        )
    }

    func httpTypesResponse() throws -> HTTPResponse {
        guard (0...999).contains(status.code) else {
            throw DaylilyHTTPTypesError.invalidStatusCode(status.code)
        }
        guard Self.isValidReasonPhrase(status.reasonPhrase) else {
            throw DaylilyHTTPTypesError.invalidReasonPhrase(status.reasonPhrase)
        }

        return HTTPResponse(
            status: HTTPResponse.Status(code: status.code, reasonPhrase: status.reasonPhrase),
            headerFields: try headers.httpTypesHeaderFields()
        )
    }

    private static func isValidReasonPhrase(_ reasonPhrase: String) -> Bool {
        reasonPhrase.utf8.allSatisfy { byte in
            switch byte {
            case 0x09, 0x20:
                true
            case 0x21...0x7E, 0x80...0xFF:
                true
            default:
                false
            }
        }
    }
}

public extension Headers {
    init(httpTypesHeaderFields: HTTPFields) {
        self.init(
            httpTypesHeaderFields.map { field in
                HeaderField(
                    name: field.name.rawName,
                    value: field.value,
                    indexingStrategy: HeaderField.DynamicTableIndexingStrategy(field.indexingStrategy)
                )
            }
        )
    }

    func httpTypesHeaderFields() throws -> HTTPFields {
        var httpFields = HTTPFields()
        httpFields.reserveCapacity(fields.count)

        for field in fields {
            guard let name = HTTPField.Name(field.name) else {
                throw DaylilyHTTPTypesError.invalidHeaderName(field.name)
            }
            guard HTTPField.isValidValue(field.value) else {
                throw DaylilyHTTPTypesError.invalidHeaderValue(name: field.name, value: field.value)
            }

            var httpField = HTTPField(name: name, value: field.value)
            httpField.indexingStrategy = HTTPField.DynamicTableIndexingStrategy(field.indexingStrategy)
            httpFields.append(httpField)
        }

        return httpFields
    }
}

private extension HeaderField.DynamicTableIndexingStrategy {
    init(_ strategy: HTTPField.DynamicTableIndexingStrategy) {
        switch strategy {
        case .prefer:
            self = .prefer
        case .avoid:
            self = .avoid
        case .disallow:
            self = .disallow
        default:
            self = .automatic
        }
    }
}

private extension HTTPField.DynamicTableIndexingStrategy {
    init(_ strategy: HeaderField.DynamicTableIndexingStrategy) {
        switch strategy {
        case .automatic:
            self = .automatic
        case .prefer:
            self = .prefer
        case .avoid:
            self = .avoid
        case .disallow:
            self = .disallow
        }
    }
}

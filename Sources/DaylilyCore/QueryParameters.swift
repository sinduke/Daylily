@dynamicMemberLookup
public struct QueryParameters: Equatable, Sendable {
    private let storage: [String: String]

    public init(_ storage: [String: String] = [:]) {
        self.storage = storage
    }

    public subscript(_ name: String) -> String? {
        storage[name]
    }

    public subscript(dynamicMember name: String) -> String? {
        storage[name]
    }

    public func require<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value {
        guard let value = try get(name, as: type) else {
            throw QueryParameterError.missing(name: name)
        }

        return value
    }

    public func get<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value? {
        guard let rawValue = storage[name] else {
            return nil
        }

        guard let value = Value.decodeParameter(rawValue) else {
            throw QueryParameterError.invalid(name: name, expected: Value.parameterTypeDescription)
        }

        return value
    }
}

public enum QueryParameterError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)

    public var status: Status {
        .badRequest
    }

    public var reason: String {
        switch self {
        case let .missing(name):
            return "Missing query parameter: \(name)"
        case let .invalid(name, expected):
            return "Invalid query parameter \(name): expected \(expected)"
        }
    }
}

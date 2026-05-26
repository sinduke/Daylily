@dynamicMemberLookup
public struct Parameters: Equatable, Sendable {
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
            throw ParameterError.missing(name: name)
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
            throw ParameterError.invalid(name: name, expected: Value.parameterTypeDescription)
        }

        return value
    }
}

public protocol ParameterDecodable: Sendable {
    static var parameterTypeDescription: String { get }
    static func decodeParameter(_ value: String) -> Self?
}

public extension ParameterDecodable {
    static var parameterTypeDescription: String {
        String(describing: Self.self)
    }
}

extension String: ParameterDecodable {
    public static func decodeParameter(_ value: String) -> String? {
        value
    }
}

extension Int: ParameterDecodable {
    public static func decodeParameter(_ value: String) -> Int? {
        Int(value)
    }
}

extension Double: ParameterDecodable {
    public static func decodeParameter(_ value: String) -> Double? {
        Double(value)
    }
}

extension Bool: ParameterDecodable {
    public static func decodeParameter(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}

public enum ParameterError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)

    public var status: Status {
        .badRequest
    }

    public var reason: String {
        switch self {
        case let .missing(name):
            return "Missing path parameter: \(name)"
        case let .invalid(name, expected):
            return "Invalid path parameter \(name): expected \(expected)"
        }
    }
}

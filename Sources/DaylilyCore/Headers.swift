public struct Headers: Equatable, Sendable, ExpressibleByDictionaryLiteral {
    private var storage: [String: String]

    public init(_ values: [String: String] = [:]) {
        var normalized: [String: String] = [:]
        for (name, value) in values {
            normalized[Self.normalize(name)] = value
        }
        self.storage = normalized
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }

    public subscript(_ name: String) -> String? {
        get {
            storage[Self.normalize(name)]
        }
        set {
            storage[Self.normalize(name)] = newValue
        }
    }

    public var all: [(name: String, value: String)] {
        storage.map { ($0.key, $0.value) }
    }

    public func require<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value {
        guard let value = try get(name, as: type) else {
            throw HeaderError.missing(name: name)
        }

        return value
    }

    public func get<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value? {
        guard let rawValue = self[name] else {
            return nil
        }

        guard let value = Value.decodeParameter(rawValue) else {
            throw HeaderError.invalid(name: name, expected: Value.parameterTypeDescription)
        }

        return value
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }
}

public enum HeaderError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)

    public var status: Status {
        .badRequest
    }

    public var reason: String {
        switch self {
        case let .missing(name):
            return "Missing header: \(name)"
        case let .invalid(name, expected):
            return "Invalid header \(name): expected \(expected)"
        }
    }
}

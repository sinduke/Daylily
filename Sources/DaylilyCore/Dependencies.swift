public struct Dependencies: Sendable {
    private var values: [ObjectIdentifier: any Sendable]

    public init() {
        self.values = [:]
    }

    public mutating func register<Value: Sendable>(_ value: Value) {
        values[ObjectIdentifier(Value.self)] = value
    }

    public func get<Value: Sendable>(_ type: Value.Type = Value.self) -> Value? {
        values[ObjectIdentifier(type)] as? Value
    }

    public func require<Value: Sendable>(_ type: Value.Type = Value.self) throws -> Value {
        guard let value = get(type) else {
            throw DependencyError.missing(type)
        }

        return value
    }
}

public struct DependencyError: ResponseError {
    public let typeName: String

    public static func missing<Value>(_ type: Value.Type) -> DependencyError {
        DependencyError(typeName: String(reflecting: type))
    }

    public var status: Status {
        .internalServerError
    }

    public var reason: String {
        "Missing dependency: \(typeName)"
    }
}

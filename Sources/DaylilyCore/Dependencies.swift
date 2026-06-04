public struct DependencyKey<Value>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

@propertyWrapper
public struct Dependency<Value: Sendable>: Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value, _ key: DependencyKey<Value>) {
        self.wrappedValue = wrappedValue
    }
}

public struct Dependencies: Sendable {
    private var values: [ObjectIdentifier: any Sendable]
    private var keyedValues: [KeyedDependencyID: any Sendable]

    public init() {
        self.values = [:]
        self.keyedValues = [:]
    }

    public mutating func register<Value: Sendable>(_ value: Value) {
        values[ObjectIdentifier(Value.self)] = value
    }

    public mutating func register<Value: Sendable>(
        _ value: Value,
        for key: DependencyKey<Value>
    ) {
        keyedValues[KeyedDependencyID(key)] = value
    }

    public func get<Value: Sendable>(_ type: Value.Type = Value.self) -> Value? {
        values[ObjectIdentifier(type)] as? Value
    }

    public func get<Value: Sendable>(_ key: DependencyKey<Value>) -> Value? {
        keyedValues[KeyedDependencyID(key)] as? Value
    }

    public func require<Value: Sendable>(_ type: Value.Type = Value.self) throws -> Value {
        guard let value = get(type) else {
            throw DependencyError.missing(type)
        }

        return value
    }

    public func require<Value: Sendable>(_ key: DependencyKey<Value>) throws -> Value {
        guard let value = get(key) else {
            throw DependencyError.missing(key)
        }

        return value
    }
}

public struct DependencyError: ResponseError {
    public let typeName: String
    public let keyName: String?

    public static func missing<Value>(_ type: Value.Type) -> DependencyError {
        DependencyError(typeName: String(reflecting: type), keyName: nil)
    }

    public static func missing<Value>(_ key: DependencyKey<Value>) -> DependencyError {
        DependencyError(typeName: String(reflecting: Value.self), keyName: key.name)
    }

    public var status: Status {
        .internalServerError
    }

    public var reason: String {
        if let keyName {
            return "Missing dependency: \(typeName) for key \(keyName)"
        }

        return "Missing dependency: \(typeName)"
    }
}

private struct KeyedDependencyID: Hashable, Sendable {
    let typeID: ObjectIdentifier
    let name: String

    init<Value>(_ key: DependencyKey<Value>) {
        self.typeID = ObjectIdentifier(Value.self)
        self.name = key.name
    }
}

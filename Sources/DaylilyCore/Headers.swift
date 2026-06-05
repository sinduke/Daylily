public struct HeaderField: Equatable, Sendable {
    public enum DynamicTableIndexingStrategy: Equatable, Sendable {
        case automatic
        case prefer
        case avoid
        case disallow
    }

    public var name: String
    public var value: String
    public var indexingStrategy: DynamicTableIndexingStrategy

    public init(
        name: String,
        value: String,
        indexingStrategy: DynamicTableIndexingStrategy = .automatic
    ) {
        self.name = name
        self.value = value
        self.indexingStrategy = indexingStrategy
    }
}

public struct Headers: Equatable, Sendable, ExpressibleByDictionaryLiteral {
    private var storage: [HeaderField]

    public init(_ values: [String: String] = [:]) {
        self.storage = values.map { HeaderField(name: $0.key, value: $0.value) }
    }

    public init(_ fields: [HeaderField]) {
        self.storage = fields
    }

    public init(fields: [(name: String, value: String)]) {
        self.storage = fields.map { HeaderField(name: $0.name, value: $0.value) }
    }

    public init(dictionaryLiteral elements: (String, String)...) {
        self.storage = elements.map { HeaderField(name: $0.0, value: $0.1) }
    }

    public subscript(_ name: String) -> String? {
        get {
            values(for: name).last
        }
        set {
            if let newValue {
                replaceValues(for: name, with: [newValue])
            } else {
                replaceValues(for: name, with: [])
            }
        }
    }

    public subscript(values name: String) -> [String] {
        get {
            values(for: name)
        }
        set {
            replaceValues(for: name, with: newValue)
        }
    }

    public var all: [(name: String, value: String)] {
        storage.map { ($0.name, $0.value) }
    }

    public var fields: [HeaderField] {
        storage
    }

    public mutating func add(
        name: String,
        value: String,
        indexingStrategy: HeaderField.DynamicTableIndexingStrategy = .automatic
    ) {
        storage.append(HeaderField(name: name, value: value, indexingStrategy: indexingStrategy))
    }

    public mutating func remove(_ name: String) {
        replaceValues(for: name, with: [])
    }

    public func values(for name: String) -> [String] {
        let normalizedName = Self.normalize(name)
        return storage.compactMap { field in
            Self.normalize(field.name) == normalizedName ? field.value : nil
        }
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

    private mutating func replaceValues(for name: String, with values: [String]) {
        let normalizedName = Self.normalize(name)
        var replaced = false
        var updated: [HeaderField] = []
        updated.reserveCapacity(storage.count + values.count)

        for field in storage {
            guard Self.normalize(field.name) == normalizedName else {
                updated.append(field)
                continue
            }

            guard !replaced else {
                continue
            }

            updated.append(contentsOf: values.map { HeaderField(name: name, value: $0) })
            replaced = true
        }

        if !replaced {
            updated.append(contentsOf: values.map { HeaderField(name: name, value: $0) })
        }

        storage = updated
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

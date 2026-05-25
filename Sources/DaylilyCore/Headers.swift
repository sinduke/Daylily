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

    private static func normalize(_ name: String) -> String {
        name.lowercased()
    }
}

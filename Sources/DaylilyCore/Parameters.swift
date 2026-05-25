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
}

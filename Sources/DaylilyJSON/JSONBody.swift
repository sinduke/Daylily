@propertyWrapper
public struct JSONBody<Value: Decodable & Sendable>: Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

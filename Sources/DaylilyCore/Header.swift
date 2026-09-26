@propertyWrapper
public struct Header<Value: Sendable>: Sendable {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(wrappedValue: Value, _: String) {
        self.wrappedValue = wrappedValue
    }
}

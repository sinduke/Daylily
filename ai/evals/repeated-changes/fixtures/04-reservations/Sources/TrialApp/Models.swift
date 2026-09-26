import DaylilyCore
public struct ReserveInput: Codable, Sendable { public let key: String; public let quantity: Int }
public struct Receipt: Codable, Sendable, Equatable {
    public let key: String; public let quantity: Int; public let remaining: Int
    public init(key: String, quantity: Int, remaining: Int) { self.key=key; self.quantity=quantity; self.remaining=remaining }
}
public struct Stock: Codable, Sendable { public let available: Int; public init(available: Int) { self.available=available } }

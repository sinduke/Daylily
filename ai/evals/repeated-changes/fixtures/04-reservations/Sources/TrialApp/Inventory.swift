import DaylilyCore
public actor Inventory {
    private var stock: Int
    public init(stock: Int = 10) { self.stock = stock }
    public func available() -> Int { stock }
    public func reserve(key: String, quantity: Int) throws -> Receipt {
        return Receipt(key: key, quantity: quantity, remaining: stock)
    }
}

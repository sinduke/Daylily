public struct Note: Codable, Sendable, Equatable {
    public let id: Int; public let text: String
    public init(id: Int, text: String) { self.id=id; self.text=text }
}
public struct NewNote: Codable, Sendable { public let text: String }

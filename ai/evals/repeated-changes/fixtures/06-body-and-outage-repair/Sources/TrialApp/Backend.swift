public struct EchoInput: Codable, Sendable { public let text: String }
public struct EchoOutput: Codable, Sendable { public let text: String }
public enum BackendFailure: Error { case unavailable }
public actor EchoBackend {
    private var available: Bool
    public init(available: Bool = true) { self.available=available }
    public func setAvailable(_ value: Bool) { available=value }
    public func echo(_ text: String) throws -> String {
        guard available else { throw BackendFailure.unavailable }
        return text
    }
}

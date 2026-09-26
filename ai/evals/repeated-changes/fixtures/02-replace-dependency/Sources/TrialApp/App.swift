import DaylilyCore

public protocol GreetingProvider: Sendable {
    func greet(_ name: String) -> String
}
public struct CasualGreeting: GreetingProvider {
    public init() {}
    public func greet(_ name: String) -> String { "Hi, \(name)!" }
}
public struct FormalGreeting: GreetingProvider {
    public init() {}
    public func greet(_ name: String) -> String { "Welcome, \(name)." }
}
public enum ReplaceDependency {
    public static func application() -> Application {
        Application {
            Get("/greetings/:name") { request in
                let name = try request.parameters.require("name", as: String.self)
                return CasualGreeting().greet(name)
            }.describe(
                operationID: "greet", inputs: [.path("name", type: "String")],
                responses: [.response(.ok, contentType: "text/plain", type: "String")]
            )
        }
    }
}

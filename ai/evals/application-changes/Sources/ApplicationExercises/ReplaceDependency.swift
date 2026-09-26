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

/// Reference result for task 02: only the composition root chooses an implementation.
public enum ReplaceDependency {
    public static let greeting = DependencyKey<any GreetingProvider>("greeting-provider")

    public static func application(provider: any GreetingProvider = FormalGreeting()) -> Application {
        Application(dependencies: { dependencies in
            dependencies.register(provider, for: greeting)
        }) {
            Get("/greetings/:name") { request in
                let name = try request.parameters.require("name", as: String.self)
                let provider = try request.dependencies.require(greeting)
                return provider.greet(name)
            }.describe(
                operationID: "greet",
                inputs: [.path("name", type: "String")],
                responses: [.response(.ok, contentType: "text/plain", type: "String")]
            )
        }
    }
}

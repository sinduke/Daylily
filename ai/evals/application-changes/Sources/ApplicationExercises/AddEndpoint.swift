import DaylilyCore
import DaylilyOpenAPI

/// Reference result for task 01: preserve health and add a described, typed endpoint.
public enum AddEndpoint {
    public static func application() -> Application {
        Application {
            Get("/health") { "ok" }
            Get("/greetings/:name") { request in
                let name = try request.parameters.require("name", as: String.self)
                return "Hello, \(name)!"
            }.describe(
                operationID: "greet",
                inputs: [.path("name", type: "String")],
                responses: [.response(.ok, contentType: "text/plain", type: "String")]
            )
        }
    }
}

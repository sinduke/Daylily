import DaylilyCore
import DaylilyOpenAPI
import Foundation

@main struct ExportSchema {
    static func main() throws {
        var components = OpenAPIComponents()
        components.registerSchema(.object(properties: [
            "message": .string(),
            "labels": .array(items: .string(enum: ["swift", "daylily"])),
        ], required: ["message", "labels"]), named: "Greeting")
        components.registerSchema(.object(properties: [
            "message": .string(),
        ], required: ["message"]), named: "EchoInput")

        // Runtime metadata is the contract source. Generated APIProtocol handlers own execution.
        let contract = Application {
            Get("/greetings/:name") { "contract" }.describe(
                summary: "Greet someone", operationID: "getGreeting",
                inputs: [.path("name", type: "String")],
                responses: [.response(.ok, contentType: "application/json", type: "Greeting")]
            )
            Post("/echo") { "contract" }.describe(
                operationID: "echo", requestBody: .json("EchoInput"),
                responses: [.response(.ok, contentType: "application/json", type: "Greeting")]
            )
        }
        let document = try contract.validatedOpenAPI(title: "Daylily generated API", version: "1.0.0", components: components)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document) + Data("\n".utf8)
        if let path = CommandLine.arguments.dropFirst().first {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } else {
            FileHandle.standardOutput.write(data)
        }
    }
}

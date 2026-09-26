import TrialApp
import DaylilyCore
import DaylilyOpenAPI
import DaylilyTesting
import Foundation
import Testing

@Suite struct AddEndpointAcceptance {
    @Test func endpointWorksAndHealthIsPreserved() async throws {
        let client = TestClient(AddEndpoint.application())
        let health = try await client.get("/health")
        try health.requireStatus(.ok)
        try health.requireBody("ok")
        let greeting = try await client.get("/greetings/Ada")
        try greeting.requireStatus(.ok)
        try greeting.requireBody("Hello, Ada!")
        let missingName = try await client.get("/greetings")
        try missingName.requireStatus(.notFound)
    }

    @Test func contractDescribesTheRuntimeEndpoint() throws {
        let document = try AddEndpoint.application().validatedOpenAPI(title: "Exercise", version: "1")
        let operation = try #require(document.paths["/greetings/{name}"]?["get"])
        #expect(operation.operationID == "greet")
        let parameter = try #require(operation.parameters.first)
        #expect(parameter.name == "name" && parameter.location == "path" && parameter.required)
        #expect(operation.responses["200"]?.content?["text/plain"]?.schema.type == "string")
    }
}

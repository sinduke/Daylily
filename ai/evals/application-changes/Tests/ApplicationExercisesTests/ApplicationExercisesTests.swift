import ApplicationExercises
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

@Suite struct ReplaceDependencyAcceptance {
    private struct TestGreeting: GreetingProvider {
        func greet(_ name: String) -> String { "Test provider received: \(name)" }
    }

    @Test func compositionRootCanSwapProtocolImplementations() async throws {
        let formal = try await TestClient(ReplaceDependency.application()).get("/greetings/Ada")
        try formal.requireBody("Welcome, Ada.")
        let casual = try await TestClient(ReplaceDependency.application(provider: CasualGreeting())).get("/greetings/Ada")
        try casual.requireBody("Hi, Ada!")
        let test = try await TestClient(ReplaceDependency.application(provider: TestGreeting())).get("/greetings/Grace")
        try test.requireBody("Test provider received: Grace")
    }

    @Test func dependencyReplacementPreservesTheRouteContract() throws {
        let before = ReplaceDependency.application(provider: CasualGreeting()).describeRoutes()
        let after = ReplaceDependency.application(provider: FormalGreeting()).describeRoutes()
        #expect(before == after)
    }
}

@Suite struct EvolveDTOAcceptance {
    @Test func authorIsReturnedAndMissingOrInvalidAuthorsAreRejected() async throws {
        let client = TestClient(EvolveDTO.application())
        let response = try await client.postJSON("/books", body: EvolveDTO.CreateBookInput(title: "Swift", author: "Ada"))
        try response.requireStatus(.created)
        let book = try response.json(EvolveDTO.Book.self)
        #expect(book.id == 1 && book.title == "Swift" && book.author == "Ada")
        for invalid in [#"{"title":"Swift"}"#, #"{"title":"Swift","author":42}"#] {
            let response = try await client.post("/books", headers: ["content-type": "application/json"], body: invalid)
            try response.requireStatus(.badRequest)
        }
    }

    @Test func requiredDTOFieldsAndResponseReferencesAreExported() throws {
        let document = try EvolveDTO.application().validatedOpenAPI(
            title: "Books", version: "2", components: EvolveDTO.components()
        )
        let operation = try #require(document.paths["/books"]?["post"])
        #expect(operation.requestBody?.content["application/json"]?.schema.reference == "#/components/schemas/CreateBookInput")
        #expect(operation.responses["201"]?.content?["application/json"]?.schema.reference == "#/components/schemas/Book")
        // Inspect encoded output, the contract that external clients actually consume.
        let root = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        let components = try #require(root["components"] as? [String: Any])
        let schemas = try #require(components["schemas"] as? [String: [String: Any]])
        for name in ["CreateBookInput", "Book"] {
            let schema = try #require(schemas[name])
            #expect((schema["required"] as? [String])?.contains("author") == true)
            let properties = try #require(schema["properties"] as? [String: [String: String]])
            #expect(properties["author"]?["type"] == "string")
        }
    }
}

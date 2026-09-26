import TrialApp
import DaylilyCore
import DaylilyOpenAPI
import DaylilyTesting
import Foundation
import Testing

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

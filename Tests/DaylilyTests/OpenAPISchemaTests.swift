import DaylilyCore
import DaylilyOpenAPI
import Foundation
import Testing

@Suite struct OpenAPISchemaTests {
    @Test func registeredSchemasExportReferencesAndRoundTrip() throws {
        var components = OpenAPIComponents()
        components.registerSchema(.object(properties: [
            "name": .string(),
            "roles": .array(items: .string(enum: ["reader", "writer"])),
            "manager": .reference("User"),
        ], required: ["name", "roles"]), named: "User")
        components.registerSecurityScheme(.bearer(format: "JWT"), named: "bearerAuth")
        let app = Application {
            Post("/users") { "created" }
                .describe(operationID: "createUser", requestBody: .json("User"), responses: [
                    .response(.created, contentType: "application/json", type: "User"),
                ], security: [.requirement("bearerAuth")])
        }
        let document = try app.validatedOpenAPI(title: "Users", version: "1", components: components)
        let schema = try #require(document.paths["/users"]?["post"]?.requestBody?.content["application/json"]?.schema)
        #expect(schema.reference == "#/components/schemas/User")
        let data = try JSONEncoder().encode(document)
        #expect(try JSONDecoder().decode(OpenAPIDocument.self, from: data) == document)
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedComponents = try #require(root["components"] as? [String: Any])
        #expect(encodedComponents["schemas"] != nil)
        let encodedReference = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(schema)) as? [String: Any])
        #expect(encodedReference["$ref"] as? String == "#/components/schemas/User")
        #expect(encodedReference["type"] == nil)
    }

    @Test func unknownSecuritySchemeFailsWithActionableLocation() throws {
        let app = Application {
            Get("/private") { "private" }.describe(security: [.requirement("missing")])
        }
        // The legacy nonthrowing export stays available.
        let document = app.openAPI(title: "Legacy", version: "1")
        do {
            try document.validate()
            Issue.record("Expected an unknown security scheme failure")
        } catch let error as OpenAPIValidationError {
            #expect(error.location == "#/paths/~1private/get/security")
            #expect(error.reason.contains("missing"))
            #expect(error.reason.contains("Register"))
        }
    }

    @Test func invalidSchemasFailAndRecursiveReferencesPass() throws {
        func document(_ schemas: [String: OpenAPISchema]) -> OpenAPIDocument {
            .init(info: .init(title: "Test", version: "1"), paths: [:], components: .init(schemas: schemas))
        }
        #expect(throws: OpenAPIValidationError.self) {
            try document(["User": .reference("Missing")]).validate()
        }
        #expect(throws: OpenAPIValidationError.self) {
            try document(["User": .object(properties: [:], required: ["name"])]).validate()
        }
        #expect(throws: OpenAPIValidationError.self) {
            try document(["Users": .init(type: "array")]).validate()
        }
        #expect(throws: OpenAPIValidationError.self) {
            try document(["Role": .string(enum: [])]).validate()
        }
        try document(["Tree": .object(properties: ["children": .array(items: .reference("Tree"))])]).validate()
    }

    @Test func partialComponentsDecodeAndLegacySchemaRemainCompatible() throws {
        let components = try JSONDecoder().decode(OpenAPIComponents.self, from: Data(#"{"schemas":{"Name":{"type":"string"}}}"#.utf8))
        #expect(components.securitySchemes.isEmpty)
        let schema = OpenAPISchema(type: "object", swiftType: "UnregisteredDTO")
        #expect(try JSONDecoder().decode(OpenAPISchema.self, from: JSONEncoder().encode(schema)) == schema)
        let document = OpenAPIBuilder().document(for: [
            .init(method: .get, path: "/legacy", metadata: .init(responses: [
                .response(.ok, contentType: "application/json", type: "UnregisteredDTO"),
            ])),
        ], title: "Legacy", version: "1")
        #expect(document.components == nil)
        #expect(document.paths["/legacy"]?["get"]?.responses["200"]?.content?["application/json"]?.schema.swiftType == "UnregisteredDTO")
    }

    @Test func securitySchemeValidationChecksShapeAndVersionSpecificRequirements() throws {
        var document = OpenAPIDocument(info: .init(title: "Auth", version: "1"), paths: [:], components: .init(
            securitySchemes: ["key": .apiKey(name: "x-api-key")]
        ))
        try document.validate()
        document.components?.securitySchemes["key"] = .init(type: "apiKey")
        #expect(throws: OpenAPIValidationError.self) { try document.validate() }
        document.components?.securitySchemes["key"] = .basic
        document.paths["/private"] = ["get": .init(responses: ["200": .init(description: "OK")], security: [["key": ["read"]]])]
        try document.validate()
        document.openapi = "3.0.3"
        #expect(throws: OpenAPIValidationError.self) { try document.validate() }
    }

    @Test func pathInputsAndOperationIDsAreChecked() throws {
        let app = Application { Get("/users/:id") { "user" } }
        #expect(throws: OpenAPIValidationError.self) {
            try app.validatedOpenAPI(title: "Missing path contract", version: "1")
        }
        let duplicate = Application {
            Get("/first") { "first" }.describe(operationID: "duplicate")
            Get("/second") { "second" }.describe(operationID: "duplicate")
        }
        #expect(throws: OpenAPIValidationError.self) {
            try duplicate.validatedOpenAPI(title: "Duplicate", version: "1")
        }
    }
}

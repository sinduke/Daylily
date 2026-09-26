import DaylilyCore
import DaylilyOpenAPI
import Foundation
import Testing

@Suite struct OpenAPISchemaTests {
    @Test func nullableSchemasKeepPresenceSeparateAndRoundTrip() throws {
        let schema = OpenAPISchema.object(properties: [
            "requiredNullable": .string().nullable(),
            "optionalNullable": .string(enum: ["draft", "sent"]).nullable(),
            "optionalNonNull": .string(),
            "nullableList": .array(items: .reference("NullableName")).nullable(),
        ], required: ["requiredNullable"])
        let document = OpenAPIDocument(info: .init(title: "Nullable", version: "1"), paths: [:],
            components: .init(schemas: ["Payload": schema, "NullableName": .string().nullable()]))
        try document.validate()
        let data = try JSONEncoder().encode(document)
        #expect(try JSONDecoder().decode(OpenAPIDocument.self, from: data) == document)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(schema)) as? [String: Any])
        let properties = try #require(encoded["properties"] as? [String: [String: Any]])
        #expect(encoded["required"] as? [String] == ["requiredNullable"])
        #expect(properties["requiredNullable"]?["type"] as? [String] == ["string", "null"])
        let values = try #require(properties["optionalNullable"]?["enum"] as? [Any])
        #expect(values.count == 3)
        #expect(values.last is NSNull)
        #expect(schema.properties?["requiredNullable"]?.isNullable == true)
        #expect(schema.properties?["optionalNonNull"]?.isNullable == false)
    }

    @Test func nullableDecodePreservesEnumIntersectionAndRejectsUnions() throws {
        for (json, nullable) in [
            (#"{"type":["null","string"],"enum":["a",null]}"#, true),
            (#"{"type":["string","null"],"enum":["a"]}"#, false),
            (#"{"type":["string","null"],"enum":[null]}"#, true),
        ] {
            let schema = try JSONDecoder().decode(OpenAPISchema.self, from: Data(json.utf8))
            #expect(schema.isNullable == nullable)
            #expect(try JSONDecoder().decode(OpenAPISchema.self, from: JSONEncoder().encode(schema)) == schema)
            try OpenAPIDocument(info: .init(title: "Enum", version: "1"), paths: [:], components: .init(schemas: ["Value": schema])).validate()
        }
        for json in [#"{"type":["string","integer"]}"#, #"{"type":["string","null","integer"]}"#,
                     #"{"type":["null","null"]}"#, #"{"type":["string","null"],"enum":[null,null]}"#] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(OpenAPISchema.self, from: Data(json.utf8))
            }
        }
    }

    @Test func nullableReferenceWrappersAndOpenAPI30AreRejected() throws {
        var document = OpenAPIDocument(info: .init(title: "Nullable", version: "1"), paths: [:],
            components: .init(schemas: ["Name": .string(), "Bad": .reference("Name").nullable()]))
        #expect(throws: OpenAPIValidationError.self) { try document.validate() }
        #expect(throws: EncodingError.self) { try JSONEncoder().encode(document) }
        document.components?.schemas["Bad"] = .string().nullable()
        document.openapi = "3.0.3"
        #expect(throws: OpenAPIValidationError.self) { try document.validate() }
    }

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

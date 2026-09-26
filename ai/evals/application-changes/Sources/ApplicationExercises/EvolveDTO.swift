import DaylilyCore
import DaylilyJSON
import DaylilyOpenAPI

/// Reference result for task 03: the required author field changes payloads and schemas together.
public enum EvolveDTO {
    public struct CreateBookInput: Codable, Sendable {
        public let title: String
        public let author: String
        public init(title: String, author: String) { self.title = title; self.author = author }
    }

    public struct Book: Codable, Equatable, Sendable {
        public let id: Int
        public let title: String
        public let author: String
    }

    public static func application() -> Application {
        Application {
            Post("/books") { request in
                let input = try await request.json(CreateBookInput.self)
                return JSON(Book(id: 1, title: input.title, author: input.author), status: .created)
            }.describe(
                operationID: "createBook", requestBody: .json("CreateBookInput"),
                responses: [.response(.created, contentType: "application/json", type: "Book")]
            )
        }
    }

    public static func components() -> OpenAPIComponents {
        .init(schemas: [
            "CreateBookInput": .object(properties: ["title": .string(), "author": .string()], required: ["title", "author"]),
            "Book": .object(properties: [
                "id": .init(type: "integer", format: "int64"), "title": .string(), "author": .string(),
            ], required: ["id", "title", "author"]),
        ])
    }
}

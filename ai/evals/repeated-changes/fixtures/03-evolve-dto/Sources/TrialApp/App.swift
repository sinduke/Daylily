import DaylilyCore
import DaylilyJSON
import DaylilyOpenAPI

public enum EvolveDTO {
    public struct CreateBookInput: Codable, Sendable {
        public let title: String
        public init(title: String) { self.title = title }
    }
    public struct Book: Codable, Equatable, Sendable {
        public let id: Int
        public let title: String
    }
    public static func application() -> Application {
        Application {
            Post("/books") { request in
                let input = try await request.json(CreateBookInput.self)
                return JSON(Book(id: 1, title: input.title), status: .created)
            }.describe(
                operationID: "createBook", requestBody: .json("CreateBookInput"),
                responses: [.response(.created, contentType: "application/json", type: "Book")]
            )
        }
    }
    public static func components() -> OpenAPIComponents {
        .init(schemas: [
            "CreateBookInput": .object(properties: ["title": .string()], required: ["title"]),
            "Book": .object(properties: ["id": .init(type: "integer", format: "int64"), "title": .string()], required: ["id", "title"]),
        ])
    }
}

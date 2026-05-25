public struct Status: Equatable, Sendable {
    public let code: Int
    public let reasonPhrase: String

    public init(_ code: Int, reasonPhrase: String) {
        self.code = code
        self.reasonPhrase = reasonPhrase
    }

    public static let ok = Status(200, reasonPhrase: "OK")
    public static let created = Status(201, reasonPhrase: "Created")
    public static let noContent = Status(204, reasonPhrase: "No Content")
    public static let badRequest = Status(400, reasonPhrase: "Bad Request")
    public static let payloadTooLarge = Status(413, reasonPhrase: "Payload Too Large")
    public static let notFound = Status(404, reasonPhrase: "Not Found")
    public static let internalServerError = Status(500, reasonPhrase: "Internal Server Error")
}

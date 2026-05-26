public struct RouteMetadata: Equatable, Sendable {
    public var summary: String?
    public var description: String?
    public var tags: [String]
    public var operationID: String?
    public var inputs: [RouteInputMetadata]
    public var requestBody: RouteBodyMetadata?
    public var responses: [RouteResponseMetadata]

    public init(
        summary: String? = nil,
        description: String? = nil,
        tags: [String] = [],
        operationID: String? = nil,
        inputs: [RouteInputMetadata] = [],
        requestBody: RouteBodyMetadata? = nil,
        responses: [RouteResponseMetadata] = []
    ) {
        self.summary = summary
        self.description = description
        self.tags = tags
        self.operationID = operationID
        self.inputs = inputs
        self.requestBody = requestBody
        self.responses = responses
    }

    public static let empty = RouteMetadata()
}

public enum RouteInputLocation: String, Equatable, Sendable {
    case path
    case query
    case header
}

public struct RouteInputMetadata: Equatable, Sendable {
    public var location: RouteInputLocation
    public var name: String
    public var typeName: String
    public var required: Bool

    public init(
        location: RouteInputLocation,
        name: String,
        typeName: String,
        required: Bool = true
    ) {
        self.location = location
        self.name = name
        self.typeName = typeName
        self.required = required
    }

    public static func path(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata {
        RouteInputMetadata(location: .path, name: name, typeName: typeName, required: required)
    }

    public static func query(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata {
        RouteInputMetadata(location: .query, name: name, typeName: typeName, required: required)
    }

    public static func header(_ name: String, type typeName: String, required: Bool = true) -> RouteInputMetadata {
        RouteInputMetadata(location: .header, name: name, typeName: typeName, required: required)
    }
}

public struct RouteBodyMetadata: Equatable, Sendable {
    public var contentType: String
    public var typeName: String
    public var required: Bool

    public init(contentType: String, typeName: String, required: Bool = true) {
        self.contentType = contentType
        self.typeName = typeName
        self.required = required
    }

    public static func json(_ typeName: String, required: Bool = true) -> RouteBodyMetadata {
        RouteBodyMetadata(contentType: "application/json", typeName: typeName, required: required)
    }
}

public struct RouteResponseMetadata: Equatable, Sendable {
    public var status: Status
    public var contentType: String?
    public var typeName: String?

    public init(status: Status = .ok, contentType: String? = nil, typeName: String? = nil) {
        self.status = status
        self.contentType = contentType
        self.typeName = typeName
    }

    public static func response(
        _ status: Status = .ok,
        contentType: String? = nil,
        type typeName: String? = nil
    ) -> RouteResponseMetadata {
        RouteResponseMetadata(status: status, contentType: contentType, typeName: typeName)
    }
}

public struct RouteDescription: Equatable, Sendable {
    public var method: HTTPMethod
    public var path: String
    public var metadata: RouteMetadata

    public init(method: HTTPMethod, path: String, metadata: RouteMetadata = .empty) {
        self.method = method
        self.path = path
        self.metadata = metadata
    }
}

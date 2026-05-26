import DaylilyCore

public struct OpenAPIDocument: Codable, Equatable, Sendable {
    public var openapi: String
    public var info: OpenAPIInfo
    public var paths: [String: [String: OpenAPIOperation]]

    public init(
        openapi: String = "3.1.0",
        info: OpenAPIInfo,
        paths: [String: [String: OpenAPIOperation]]
    ) {
        self.openapi = openapi
        self.info = info
        self.paths = paths
    }
}

public struct OpenAPIInfo: Codable, Equatable, Sendable {
    public var title: String
    public var version: String

    public init(title: String, version: String) {
        self.title = title
        self.version = version
    }
}

public struct OpenAPIOperation: Codable, Equatable, Sendable {
    public var summary: String?
    public var description: String?
    public var operationID: String?
    public var tags: [String]
    public var parameters: [OpenAPIParameter]
    public var requestBody: OpenAPIRequestBody?
    public var responses: [String: OpenAPIResponse]

    public init(
        summary: String? = nil,
        description: String? = nil,
        operationID: String? = nil,
        tags: [String] = [],
        parameters: [OpenAPIParameter] = [],
        requestBody: OpenAPIRequestBody? = nil,
        responses: [String: OpenAPIResponse]
    ) {
        self.summary = summary
        self.description = description
        self.operationID = operationID
        self.tags = tags
        self.parameters = parameters
        self.requestBody = requestBody
        self.responses = responses
    }

    enum CodingKeys: String, CodingKey {
        case summary
        case description
        case operationID = "operationId"
        case tags
        case parameters
        case requestBody
        case responses
    }
}

public struct OpenAPIParameter: Codable, Equatable, Sendable {
    public var name: String
    public var location: String
    public var required: Bool
    public var schema: OpenAPISchema

    public init(name: String, location: String, required: Bool, schema: OpenAPISchema) {
        self.name = name
        self.location = location
        self.required = required
        self.schema = schema
    }

    enum CodingKeys: String, CodingKey {
        case name
        case location = "in"
        case required
        case schema
    }
}

public struct OpenAPIRequestBody: Codable, Equatable, Sendable {
    public var required: Bool
    public var content: [String: OpenAPIMediaType]

    public init(required: Bool, content: [String: OpenAPIMediaType]) {
        self.required = required
        self.content = content
    }
}

public struct OpenAPIResponse: Codable, Equatable, Sendable {
    public var description: String
    public var content: [String: OpenAPIMediaType]?

    public init(description: String, content: [String: OpenAPIMediaType]? = nil) {
        self.description = description
        self.content = content
    }
}

public struct OpenAPIMediaType: Codable, Equatable, Sendable {
    public var schema: OpenAPISchema

    public init(schema: OpenAPISchema) {
        self.schema = schema
    }
}

public struct OpenAPISchema: Codable, Equatable, Sendable {
    public var type: String
    public var format: String?
    public var swiftType: String?

    public init(type: String, format: String? = nil, swiftType: String? = nil) {
        self.type = type
        self.format = format
        self.swiftType = swiftType
    }

    enum CodingKeys: String, CodingKey {
        case type
        case format
        case swiftType = "x-swift-type"
    }
}

public struct OpenAPIBuilder: Sendable {
    public init() {}

    public func document(
        for routes: [RouteDescription],
        title: String,
        version: String,
        openapi: String = "3.1.0"
    ) -> OpenAPIDocument {
        var paths: [String: [String: OpenAPIOperation]] = [:]

        for route in routes {
            let path = Self.openAPIPath(for: route.path)
            let method = route.method.rawValue.lowercased()
            paths[path, default: [:]][method] = Self.operation(for: route.metadata)
        }

        return OpenAPIDocument(
            openapi: openapi,
            info: OpenAPIInfo(title: title, version: version),
            paths: paths
        )
    }

    private static func operation(for metadata: RouteMetadata) -> OpenAPIOperation {
        OpenAPIOperation(
            summary: metadata.summary,
            description: metadata.description,
            operationID: metadata.operationID,
            tags: metadata.tags,
            parameters: metadata.inputs.map(parameter(for:)),
            requestBody: metadata.requestBody.map(requestBody(for:)),
            responses: responses(for: metadata)
        )
    }

    private static func parameter(for input: RouteInputMetadata) -> OpenAPIParameter {
        OpenAPIParameter(
            name: input.name,
            location: input.location.rawValue,
            required: input.location == .path ? true : input.required,
            schema: schema(for: input.typeName)
        )
    }

    private static func requestBody(for body: RouteBodyMetadata) -> OpenAPIRequestBody {
        OpenAPIRequestBody(
            required: body.required,
            content: [
                body.contentType: OpenAPIMediaType(schema: schema(for: body.typeName)),
            ]
        )
    }

    private static func responses(for metadata: RouteMetadata) -> [String: OpenAPIResponse] {
        let responses = metadata.responses.isEmpty ? [.response(.ok)] : metadata.responses
        var output: [String: OpenAPIResponse] = [:]

        for response in responses {
            let content = response.contentType.flatMap { contentType -> [String: OpenAPIMediaType]? in
                guard let typeName = response.typeName else {
                    return nil
                }

                return [
                    contentType: OpenAPIMediaType(schema: schema(for: typeName)),
                ]
            }

            output[String(response.status.code)] = OpenAPIResponse(
                description: response.status.reasonPhrase,
                content: content
            )
        }

        return output
    }

    private static func schema(for typeName: String) -> OpenAPISchema {
        switch simplified(typeName) {
        case "String":
            return OpenAPISchema(type: "string")
        case "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return OpenAPISchema(type: "integer", format: "int64")
        case "Double":
            return OpenAPISchema(type: "number", format: "double")
        case "Float":
            return OpenAPISchema(type: "number", format: "float")
        case "Bool":
            return OpenAPISchema(type: "boolean")
        default:
            return OpenAPISchema(type: "object", swiftType: typeName)
        }
    }

    private static func simplified(_ typeName: String) -> String {
        var value = typeName

        if value.hasPrefix("Swift.") {
            value.removeFirst("Swift.".count)
        }

        if value.hasSuffix("?") {
            value.removeLast()
        }

        return value
    }

    private static func openAPIPath(for routePath: String) -> String {
        let segments = routePath.split(separator: "/", omittingEmptySubsequences: true).map { segment in
            if segment.hasPrefix(":") || segment.hasPrefix("*") {
                return "{\(segment.dropFirst())}"
            }

            return String(segment)
        }

        return segments.isEmpty ? "/" : "/" + segments.joined(separator: "/")
    }
}

public extension Application {
    func openAPI(title: String, version: String, openapi: String = "3.1.0") -> OpenAPIDocument {
        OpenAPIBuilder().document(
            for: describeRoutes(),
            title: title,
            version: version,
            openapi: openapi
        )
    }
}

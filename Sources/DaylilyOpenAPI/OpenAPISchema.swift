/// An explicitly authored subset of OpenAPI 3.1 schemas. Swift types are not reflected.
public struct OpenAPISchema: Codable, Equatable, Sendable {
    /// Retained for compatibility. A reference has no encoded `type` keyword.
    public var type: String
    public var format: String?
    public var swiftType: String?
    public var properties: [String: OpenAPISchema]?
    public var required: [String]?
    public var enumValues: [String]?
    public var reference: String?
    private var itemStorage: Item?

    private indirect enum Item: Equatable, Sendable {
        case schema(OpenAPISchema)
    }

    public var items: OpenAPISchema? {
        get {
            guard case .schema(let schema) = itemStorage else { return nil }
            return schema
        }
        set { itemStorage = newValue.map(Item.schema) }
    }

    public init(type: String, format: String? = nil, swiftType: String? = nil) {
        self.type = type
        self.format = format
        self.swiftType = swiftType
    }

    public static func object(properties: [String: OpenAPISchema], required: [String] = []) -> Self {
        var schema = Self(type: "object")
        schema.properties = properties
        schema.required = required.isEmpty ? nil : required
        return schema
    }

    public static func array(items: OpenAPISchema) -> Self {
        var schema = Self(type: "array")
        schema.items = items
        return schema
    }

    public static func string(enum values: [String]? = nil) -> Self {
        var schema = Self(type: "string")
        schema.enumValues = values
        return schema
    }

    public static func reference(_ componentName: String) -> Self {
        var schema = Self(type: "object")
        schema.reference = "#/components/schemas/\(componentName)"
        return schema
    }

    enum CodingKeys: String, CodingKey {
        case type, format, properties, required, items
        case swiftType = "x-swift-type"
        case enumValues = "enum"
        case reference = "$ref"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reference = try container.decodeIfPresent(String.self, forKey: .reference)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "object"
        format = try container.decodeIfPresent(String.self, forKey: .format)
        swiftType = try container.decodeIfPresent(String.self, forKey: .swiftType)
        properties = try container.decodeIfPresent([String: Self].self, forKey: .properties)
        required = try container.decodeIfPresent([String].self, forKey: .required)
        enumValues = try container.decodeIfPresent([String].self, forKey: .enumValues)
        items = try container.decodeIfPresent(Self.self, forKey: .items)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let reference {
            try container.encode(reference, forKey: .reference)
        } else {
            try container.encode(type, forKey: .type)
        }
        try container.encodeIfPresent(format, forKey: .format)
        try container.encodeIfPresent(swiftType, forKey: .swiftType)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(enumValues, forKey: .enumValues)
    }
}

public struct OpenAPIComponents: Codable, Equatable, Sendable {
    public var schemas: [String: OpenAPISchema]
    public var securitySchemes: [String: OpenAPISecurityScheme]

    public init(
        schemas: [String: OpenAPISchema] = [:],
        securitySchemes: [String: OpenAPISecurityScheme] = [:]
    ) {
        self.schemas = schemas
        self.securitySchemes = securitySchemes
    }

    /// Names also match route metadata type names. Re-registering a name replaces its schema.
    public mutating func registerSchema(_ schema: OpenAPISchema, named name: String) {
        schemas[name] = schema
    }

    public mutating func registerSecurityScheme(_ scheme: OpenAPISecurityScheme, named name: String) {
        securitySchemes[name] = scheme
    }

    enum CodingKeys: String, CodingKey { case schemas, securitySchemes }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemas = try container.decodeIfPresent([String: OpenAPISchema].self, forKey: .schemas) ?? [:]
        securitySchemes = try container.decodeIfPresent([String: OpenAPISecurityScheme].self, forKey: .securitySchemes) ?? [:]
    }
}

/// Security documentation only; applications still supply authentication middleware.
public struct OpenAPISecurityScheme: Codable, Equatable, Sendable {
    public enum APIKeyLocation: String, Codable, Sendable { case header, query, cookie }

    public var type: String
    public var scheme: String?
    public var bearerFormat: String?
    public var name: String?
    public var location: APIKeyLocation?

    public init(type: String, scheme: String? = nil, bearerFormat: String? = nil,
                name: String? = nil, location: APIKeyLocation? = nil) {
        self.type = type
        self.scheme = scheme
        self.bearerFormat = bearerFormat
        self.name = name
        self.location = location
    }

    public static func bearer(format: String? = nil) -> Self {
        Self(type: "http", scheme: "bearer", bearerFormat: format)
    }

    public static var basic: Self { Self(type: "http", scheme: "basic") }

    public static func apiKey(name: String, location: APIKeyLocation = .header) -> Self {
        Self(type: "apiKey", name: name, location: location)
    }

    enum CodingKeys: String, CodingKey {
        case type, scheme, bearerFormat, name
        case location = "in"
    }
}

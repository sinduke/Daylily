public struct OpenAPIValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    public let location: String
    public let reason: String

    public init(location: String, reason: String) {
        self.location = location
        self.reason = reason
    }

    public var description: String { "Invalid OpenAPI at \(location): \(reason)" }
}

public extension OpenAPIDocument {
    /// Validates this module's supported subset, not the complete OpenAPI/JSON Schema specification.
    /// References are checked without expanding them, so recursive component schemas are supported.
    func validate() throws {
        let components = components ?? .init()
        func fail(_ location: String, _ reason: String) throws -> Never {
            throw OpenAPIValidationError(location: location, reason: reason)
        }
        func pointer(_ value: String) -> String {
            value.map { character in
                character == "~" ? "~0" : character == "/" ? "~1" : String(character)
            }.joined()
        }
        func validateName(_ name: String, at location: String) throws {
            let allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
            guard !name.isEmpty, name.allSatisfy({ allowed.contains($0) }) else {
                try fail(location, "Component names must match [A-Za-z0-9._-]+.")
            }
        }
        func validateSchema(_ schema: OpenAPISchema, at location: String) throws {
            if let reference = schema.reference {
                let prefix = "#/components/schemas/"
                guard reference.hasPrefix(prefix), components.schemas[String(reference.dropFirst(prefix.count))] != nil else {
                    try fail(location, "Unknown or unsupported schema reference '\(reference)'. Register a local schema component.")
                }
            } else if !["object", "array", "string", "integer", "number", "boolean", "null"].contains(schema.type) {
                try fail(location, "Unsupported schema type '\(schema.type)'.")
            }
            if let properties = schema.properties {
                guard schema.type == "object" else { try fail(location, "Only object schemas may declare properties.") }
                for name in properties.keys.sorted() {
                    try validateSchema(properties[name]!, at: "\(location)/properties/\(pointer(name))")
                }
            }
            if let required = schema.required {
                guard schema.type == "object", Set(required).count == required.count,
                      required.allSatisfy({ schema.properties?[$0] != nil }) else {
                    try fail(location, "Required fields must be unique, declared object properties.")
                }
            }
            if schema.type == "array", schema.items == nil {
                try fail(location, "Array schemas require an items schema.")
            }
            if let items = schema.items {
                guard schema.type == "array" else { try fail(location, "Only array schemas may declare items.") }
                try validateSchema(items, at: "\(location)/items")
            }
            if let values = schema.enumValues {
                guard schema.type == "string", !values.isEmpty, Set(values).count == values.count else {
                    try fail(location, "String enums must contain at least one unique string value.")
                }
            }
        }
        for name in components.schemas.keys.sorted() {
            let location = "#/components/schemas/\(name)"
            try validateName(name, at: location)
            try validateSchema(components.schemas[name]!, at: location)
        }
        for name in components.securitySchemes.keys.sorted() {
            let location = "#/components/securitySchemes/\(name)"
            try validateName(name, at: location)
            let scheme = components.securitySchemes[name]!
            switch scheme.type {
            case "http":
                guard let value = scheme.scheme, !value.isEmpty,
                      scheme.name == nil, scheme.location == nil else {
                    try fail(location, "HTTP security requires a scheme and cannot declare apiKey fields.")
                }
                if scheme.bearerFormat != nil, value.lowercased() != "bearer" {
                    try fail(location, "bearerFormat requires the bearer HTTP scheme.")
                }
            case "apiKey":
                guard let value = scheme.name, !value.isEmpty, scheme.location != nil,
                      scheme.scheme == nil, scheme.bearerFormat == nil else {
                    try fail(location, "API key security requires name and location, without HTTP scheme fields.")
                }
            default:
                try fail(location, "Unsupported security scheme type '\(scheme.type)'. Supported: http, apiKey.")
            }
        }
        var operationIDs = Set<String>()
        for path in paths.keys.sorted() {
            guard path.hasPrefix("/") else { try fail("#/paths/\(pointer(path))", "Paths must begin with '/'.") }
            for method in paths[path]!.keys.sorted() {
                let operation = paths[path]![method]!
                let location = "#/paths/\(pointer(path))/\(method)"
                guard ["get", "post", "put", "patch", "delete", "head", "options", "trace"].contains(method) else {
                    try fail(location, "Unsupported OpenAPI HTTP method '\(method)'.")
                }
                if let id = operation.operationID, !operationIDs.insert(id).inserted {
                    try fail(location, "Duplicate operationId '\(id)'.")
                }
                guard !operation.responses.isEmpty else { try fail(location, "An operation requires a response.") }
                for requirement in operation.security ?? [] {
                    for name in requirement.keys.sorted() {
                        guard components.securitySchemes[name] != nil else {
                            try fail("\(location)/security", "Unknown security scheme '\(name)'. Register it in components.securitySchemes.")
                        }
                        // OpenAPI 3.1 permits role names for non-OAuth schemes; 3.0 requires an empty array.
                        if openapi.hasPrefix("3.0."), !requirement[name]!.isEmpty {
                            try fail("\(location)/security", "OpenAPI 3.0 HTTP and apiKey security requirements must have empty arrays.")
                        }
                    }
                }
                let templateNames = Set(path.split(separator: "/").compactMap { segment -> String? in
                    guard segment.hasPrefix("{"), segment.hasSuffix("}") else { return nil }
                    return String(segment.dropFirst().dropLast())
                })
                var parameterKeys = Set<String>()
                var pathParameterNames = Set<String>()
                for (index, parameter) in operation.parameters.enumerated() {
                    guard ["path", "query", "header", "cookie"].contains(parameter.location), !parameter.name.isEmpty else {
                        try fail(location, "Parameters require a name and a supported location.")
                    }
                    guard parameterKeys.insert("\(parameter.location):\(parameter.name)").inserted else {
                        try fail(location, "Duplicate parameter '\(parameter.name)' in '\(parameter.location)'.")
                    }
                    if parameter.location == "path" {
                        guard parameter.required, templateNames.contains(parameter.name) else {
                            try fail(location, "Path parameter '\(parameter.name)' must be required and appear in the path template.")
                        }
                        pathParameterNames.insert(parameter.name)
                    }
                    try validateSchema(parameter.schema, at: "\(location)/parameters/\(index)/schema")
                }
                guard pathParameterNames == templateNames else {
                    try fail(location, "Every path template parameter needs explicit path input metadata.")
                }
                for mediaType in operation.requestBody?.content.keys.sorted() ?? [] {
                    try validateSchema(operation.requestBody!.content[mediaType]!.schema, at: "\(location)/requestBody/content/\(pointer(mediaType))/schema")
                }
                for status in operation.responses.keys.sorted() {
                    let response = operation.responses[status]!
                    for mediaType in response.content?.keys.sorted() ?? [] {
                        try validateSchema(response.content![mediaType]!.schema, at: "\(location)/responses/\(status)/content/\(pointer(mediaType))/schema")
                    }
                }
            }
        }
    }
}

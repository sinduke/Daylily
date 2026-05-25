import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct RouteMarkerMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public struct DaylilyServerMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var collector = RouteCollector()
        let collection = try collector.collect(
            members: declaration.memberBlock.members,
            pathPrefix: "",
            receiver: "server",
            typePrefix: "Self"
        )

        guard !collection.routes.isEmpty else {
            throw DaylilyMacroError("@DaylilyServer requires at least one @GET or @POST method.")
        }

        let routeDeclarations = collection.routes.map { $0.routeDeclaration }.joined(separator: "\n\n")
        var lines = [
            "static func main() async throws {",
            "    let server = Self()",
        ]

        if !collection.instanceDeclarations.isEmpty {
            lines.append("")
            lines.append(contentsOf: collection.instanceDeclarations.map { "    \($0)" })
        }

        lines.append("")
        lines.append("    let app = Application {")
        lines.append(routeDeclarations.indented(by: 8))
        lines.append("    }")
        lines.append("")
        lines.append("    try await app.run()")
        lines.append("}")

        let generated = lines.joined(separator: "\n")

        return [DeclSyntax(stringLiteral: generated)]
    }
}

private struct RouteCollection {
    var routes: [RouteMethod] = []
    var instanceDeclarations: [String] = []

    mutating func append(_ other: RouteCollection) {
        routes.append(contentsOf: other.routes)
        instanceDeclarations.append(contentsOf: other.instanceDeclarations)
    }
}

private struct RouteCollector {
    private var groupIndex = 0

    mutating func collect(
        members: MemberBlockItemListSyntax,
        pathPrefix: String,
        receiver: String,
        typePrefix: String
    ) throws -> RouteCollection {
        var collection = RouteCollection()

        for member in members {
            if let function = member.decl.as(FunctionDeclSyntax.self),
               let route = try RouteMethod(function, pathPrefix: pathPrefix, receiver: receiver) {
                collection.routes.append(route)
                continue
            }

            if let nestedStruct = member.decl.as(StructDeclSyntax.self),
               let group = try GroupAttribute(nestedStruct) {
                let groupName = "group\(groupIndex)"
                groupIndex += 1

                let groupType = "\(typePrefix).\(nestedStruct.name.text)"
                collection.instanceDeclarations.append("let \(groupName) = \(groupType)()")

                let nested = try collect(
                    members: nestedStruct.memberBlock.members,
                    pathPrefix: Self.join(pathPrefix, group.path),
                    receiver: groupName,
                    typePrefix: groupType
                )

                guard !nested.routes.isEmpty else {
                    throw DaylilyMacroError("@GROUP(\(group.path.swiftStringLiteral)) must contain at least one @GET or @POST method.")
                }

                collection.append(nested)
            }
        }

        return collection
    }

    fileprivate static func join(_ prefix: String, _ path: String) -> String {
        let prefix = prefix.trimmedSlashes
        let path = path.trimmedSlashes

        switch (prefix.isEmpty, path.isEmpty) {
        case (true, true):
            return "/"
        case (true, false):
            return "/" + path
        case (false, true):
            return "/" + prefix
        case (false, false):
            return "/" + prefix + "/" + path
        }
    }
}

private struct RouteMethod {
    let routeFunction: String
    let path: String
    let receiver: String
    let functionName: String
    let callPrefix: String
    let callArguments: String?

    init?(_ function: FunctionDeclSyntax, pathPrefix: String, receiver: String) throws {
        guard let routeAttribute = try RouteAttribute(function) else {
            return nil
        }

        if function.modifiers.contains(where: { modifier in
            let name = modifier.name.text
            return name == "static" || name == "class"
        }) {
            throw DaylilyMacroError("@\(routeAttribute.name) handlers must be instance methods in this MVP.")
        }

        self.routeFunction = routeAttribute.routeFunction
        self.path = RouteCollector.join(pathPrefix, routeAttribute.path)
        self.receiver = receiver
        self.functionName = function.name.text
        self.callPrefix = Self.callPrefix(for: function)
        self.callArguments = try Self.callArguments(for: function, routeName: routeAttribute.name)
    }

    var routeDeclaration: String {
        if let callArguments {
            return """
            \(routeFunction)(\(path.swiftStringLiteral)) { req in
                \(callPrefix)\(receiver).\(functionName)(\(callArguments))
            }
            """
        }

        return """
        \(routeFunction)(\(path.swiftStringLiteral)) {
            \(callPrefix)\(receiver).\(functionName)()
        }
        """
    }

    private static func callPrefix(for function: FunctionDeclSyntax) -> String {
        let signature = function.signature.description
        let needsTry = signature.contains(" throws") || signature.contains(" rethrows")
        let needsAwait = signature.contains(" async")

        switch (needsTry, needsAwait) {
        case (true, true):
            return "try await "
        case (true, false):
            return "try "
        case (false, true):
            return "await "
        case (false, false):
            return ""
        }
    }

    private static func callArguments(for function: FunctionDeclSyntax, routeName: String) throws -> String? {
        let parameters = Array(function.signature.parameterClause.parameters)

        if parameters.isEmpty {
            return nil
        }

        guard parameters.count == 1, let parameter = parameters.first else {
            throw DaylilyMacroError("@\(routeName) handlers only support zero parameters or one Request parameter in this MVP.")
        }

        let typeName = parameter.type.description.trimmed
        guard typeName == "Request" || typeName == "Daylily.Request" || typeName == "DaylilyCore.Request" else {
            throw DaylilyMacroError("@\(routeName) handler parameter must be Request in this MVP.")
        }

        let externalName = parameter.firstName.text
        if externalName == "_" {
            return "req"
        }
        return "\(externalName): req"
    }
}

private struct GroupAttribute {
    let path: String

    init?(_ group: StructDeclSyntax) throws {
        var found: GroupAttribute?

        for attributeElement in group.attributes {
            guard case let .attribute(attribute) = attributeElement else {
                continue
            }

            let name = RouteAttribute.routeName(for: attribute.attributeName.description.trimmed)
            guard name == "GROUP" else {
                continue
            }

            if found != nil {
                throw DaylilyMacroError("Group declarations may only have one @GROUP attribute.")
            }

            found = GroupAttribute(path: try RouteAttribute.path(from: attribute))
        }

        guard let found else {
            return nil
        }

        self = found
    }

    private init(path: String) {
        self.path = path
    }
}

private struct RouteAttribute {
    let name: String
    let routeFunction: String
    let path: String

    init?(_ function: FunctionDeclSyntax) throws {
        var found: RouteAttribute?

        for attributeElement in function.attributes {
            guard case let .attribute(attribute) = attributeElement else {
                continue
            }

            let name = attribute.attributeName.description.trimmed
            guard let routeFunction = Self.routeFunction(for: name) else {
                continue
            }

            if found != nil {
                throw DaylilyMacroError("Route handlers may only have one route attribute.")
            }

            found = RouteAttribute(
                name: Self.routeName(for: name),
                routeFunction: routeFunction,
                path: try Self.path(from: attribute)
            )
        }

        guard let found else {
            return nil
        }

        self = found
    }

    private init(name: String, routeFunction: String, path: String) {
        self.name = name
        self.routeFunction = routeFunction
        self.path = path
    }

    private static func routeFunction(for attributeName: String) -> String? {
        switch routeName(for: attributeName) {
        case "GET":
            return "Get"
        case "POST":
            return "Post"
        default:
            return nil
        }
    }

    fileprivate static func routeName(for attributeName: String) -> String {
        attributeName.split(separator: ".").last.map(String.init) ?? attributeName
    }

    fileprivate static func path(from attribute: AttributeSyntax) throws -> String {
        let text = attribute.description
        guard let start = text.firstIndex(of: "\"") else {
            throw DaylilyMacroError("@\(attribute.attributeName.description.trimmed) requires a string literal path.")
        }

        var index = text.index(after: start)
        var value = ""
        var isEscaped = false

        while index < text.endIndex {
            let character = text[index]

            if isEscaped {
                value.append(character)
                isEscaped = false
            } else if character == "\\" {
                value.append(character)
                isEscaped = true
            } else if character == "\"" {
                return value
            } else {
                value.append(character)
            }

            index = text.index(after: index)
        }

        throw DaylilyMacroError("@\(attribute.attributeName.description.trimmed) requires a string literal path.")
    }
}

private struct DaylilyMacroError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSlashes: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var swiftStringLiteral: String {
        "\"" + flatMap { character -> String in
            switch character {
            case "\\":
                return "\\\\"
            case "\"":
                return "\\\""
            case "\n":
                return "\\n"
            case "\r":
                return "\\r"
            case "\t":
                return "\\t"
            default:
                return String(character)
            }
        } + "\""
    }

    func indented(by spaces: Int) -> String {
        let padding = String(repeating: " ", count: spaces)
        return split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : padding + $0 }
            .joined(separator: "\n")
    }
}

@main
struct DaylilyPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DaylilyServerMacro.self,
        RouteMarkerMacro.self,
    ]
}

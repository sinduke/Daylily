@dynamicMemberLookup
public struct QueryParameters: Equatable, Sendable {
    private let storage: [QueryParameter]
    public let rawValue: String?

    public init(_ storage: [String: String] = [:]) {
        self.storage = storage.map { QueryParameter(name: $0.key, value: $0.value) }
        self.rawValue = nil
    }

    public init(_ parameters: [QueryParameter], rawValue: String? = nil) {
        self.storage = parameters
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self = Self.parse(rawValue)
    }

    public subscript(_ name: String) -> String? {
        values(for: name).last
    }

    public subscript(dynamicMember name: String) -> String? {
        self[name]
    }

    public var all: [(name: String, value: String)] {
        storage.map { ($0.name, $0.value) }
    }

    public var parameters: [QueryParameter] {
        storage
    }

    public var queryString: String? {
        if let rawValue {
            return rawValue
        }

        guard !storage.isEmpty else {
            return nil
        }

        return storage.map(\.encoded).joined(separator: "&")
    }

    public func values(for name: String) -> [String] {
        storage.compactMap { parameter in
            parameter.name == name ? parameter.value : nil
        }
    }

    public func require<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value {
        guard let value = try get(name, as: type) else {
            throw QueryParameterError.missing(name: name)
        }

        return value
    }

    public func get<Value: ParameterDecodable>(
        _ name: String,
        as type: Value.Type = Value.self
    ) throws -> Value? {
        guard let rawValue = self[name] else {
            return nil
        }

        guard let value = Value.decodeParameter(rawValue) else {
            throw QueryParameterError.invalid(name: name, expected: Value.parameterTypeDescription)
        }

        return value
    }

    static func parse(_ rawValue: String) -> QueryParameters {
        var parameters: [QueryParameter] = []

        for pair in rawValue.split(separator: "&", omittingEmptySubsequences: false) {
            guard !pair.isEmpty else {
                continue
            }

            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let rawName = String(parts[0])
            let rawParameterValue = parts.count == 2 ? String(parts[1]) : nil
            parameters.append(
                QueryParameter(
                    name: percentDecode(parts[0]),
                    value: rawParameterValue.map { percentDecode(Substring($0)) } ?? "",
                    hasValue: rawParameterValue != nil,
                    rawName: rawName,
                    rawValue: rawParameterValue
                )
            )
        }

        return QueryParameters(parameters, rawValue: rawValue)
    }

    private static func percentDecode(_ value: Substring) -> String {
        var bytes: [UInt8] = []
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]

            if character == "+" {
                bytes.append(0x20)
                index = value.index(after: index)
                continue
            }

            if character == "%",
               let first = value.index(index, offsetBy: 1, limitedBy: value.endIndex),
               first < value.endIndex,
               let second = value.index(first, offsetBy: 1, limitedBy: value.endIndex),
               second < value.endIndex,
               let byte = hexByte(value[first], value[second]) {
                bytes.append(byte)
                index = value.index(after: second)
                continue
            }

            bytes.append(contentsOf: String(character).utf8)
            index = value.index(after: index)
        }

        return String(decoding: bytes, as: UTF8.self)
    }

    private static func hexByte(_ first: Character, _ second: Character) -> UInt8? {
        guard let high = hexValue(first), let low = hexValue(second) else {
            return nil
        }

        return high * 16 + low
    }

    private static func hexValue(_ character: Character) -> UInt8? {
        switch character {
        case "0"..."9":
            return character.asciiValue.map { $0 - Character("0").asciiValue! }
        case "a"..."f":
            return character.asciiValue.map { $0 - Character("a").asciiValue! + 10 }
        case "A"..."F":
            return character.asciiValue.map { $0 - Character("A").asciiValue! + 10 }
        default:
            return nil
        }
    }
}

public struct QueryParameter: Equatable, Sendable {
    public let name: String
    public let value: String
    public let hasValue: Bool
    public let rawName: String?
    public let rawValue: String?

    public init(name: String, value: String, hasValue: Bool = true, rawName: String? = nil, rawValue: String? = nil) {
        self.name = name
        self.value = value
        self.hasValue = hasValue
        self.rawName = rawName
        self.rawValue = rawValue
    }

    fileprivate var encoded: String {
        let name = rawName ?? Self.percentEncode(name)
        guard hasValue else {
            return name
        }

        return "\(name)=\(rawValue ?? Self.percentEncode(value))"
    }

    private static func percentEncode(_ value: String) -> String {
        let hexDigits = Array("0123456789ABCDEF".utf8)
        var encoded = ""
        for byte in value.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."),
                 UInt8(ascii: "_"),
                 UInt8(ascii: "~"):
                encoded.append(Character(UnicodeScalar(byte)))
            default:
                encoded.append("%")
                encoded.append(Character(UnicodeScalar(hexDigits[Int(byte >> 4)])))
                encoded.append(Character(UnicodeScalar(hexDigits[Int(byte & 0x0F)])))
            }
        }
        return encoded
    }
}

public enum QueryParameterError: ResponseError {
    case missing(name: String)
    case invalid(name: String, expected: String)

    public var status: Status {
        .badRequest
    }

    public var reason: String {
        switch self {
        case let .missing(name):
            return "Missing query parameter: \(name)"
        case let .invalid(name, expected):
            return "Invalid query parameter \(name): expected \(expected)"
        }
    }
}

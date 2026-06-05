public struct HTTPMethod: Equatable, Hashable, RawRepresentable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Self.isValidToken(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init?(rawValue: String) {
        self.init(rawValue)
    }

    public var description: String {
        rawValue
    }

    public static let delete = HTTPMethod(unchecked: "DELETE")
    public static let get = HTTPMethod(unchecked: "GET")
    public static let head = HTTPMethod(unchecked: "HEAD")
    public static let options = HTTPMethod(unchecked: "OPTIONS")
    public static let patch = HTTPMethod(unchecked: "PATCH")
    public static let post = HTTPMethod(unchecked: "POST")
    public static let put = HTTPMethod(unchecked: "PUT")
    public static let connect = HTTPMethod(unchecked: "CONNECT")
    public static let trace = HTTPMethod(unchecked: "TRACE")

    private init(unchecked rawValue: String) {
        self.rawValue = rawValue
    }

    private static func isValidToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy(isTokenByte)
    }

    private static func isTokenByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "!"),
             UInt8(ascii: "#"),
             UInt8(ascii: "$"),
             UInt8(ascii: "%"),
             UInt8(ascii: "&"),
             UInt8(ascii: "'"),
             UInt8(ascii: "*"),
             UInt8(ascii: "+"),
             UInt8(ascii: "-"),
             UInt8(ascii: "."),
             UInt8(ascii: "^"),
             UInt8(ascii: "_"),
             UInt8(ascii: "`"),
             UInt8(ascii: "|"),
             UInt8(ascii: "~"):
            true
        case UInt8(ascii: "0")...UInt8(ascii: "9"),
             UInt8(ascii: "A")...UInt8(ascii: "Z"),
             UInt8(ascii: "a")...UInt8(ascii: "z"):
            true
        default:
            false
        }
    }
}

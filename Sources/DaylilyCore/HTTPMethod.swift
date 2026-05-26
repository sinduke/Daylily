public enum HTTPMethod: String, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case head = "HEAD"
    case options = "OPTIONS"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"

    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue.uppercased())
    }
}

public struct Abort: Error, Sendable {
    public let status: Status
    public let reason: String

    public init(_ status: Status, reason: String? = nil) {
        self.status = status
        self.reason = reason ?? status.reasonPhrase
    }
}

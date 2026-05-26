import DaylilyCore
import Foundation

public enum TestFailure: Error, Sendable, CustomStringConvertible {
    case status(expected: Status, actual: Status)
    case body(expected: String, actual: String)
    case json(reason: String)

    public var description: String {
        switch self {
        case .status(let expected, let actual):
            "Expected status \(expected.code) \(expected.reasonPhrase), got \(actual.code) \(actual.reasonPhrase)"
        case .body(let expected, let actual):
            "Expected body \(String(reflecting: expected)), got \(String(reflecting: actual))"
        case .json(let reason):
            reason
        }
    }
}

public extension Response {
    func json<Value: Decodable>(_ type: Value.Type = Value.self) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: Data(body))
        } catch {
            throw TestFailure.json(reason: "Failed to decode JSON response as \(Value.self): \(error)")
        }
    }

    func requireStatus(_ expected: Status) throws {
        guard status == expected else {
            throw TestFailure.status(expected: expected, actual: status)
        }
    }

    func requireBody(_ expected: String) throws {
        guard bodyString == expected else {
            throw TestFailure.body(expected: expected, actual: bodyString)
        }
    }

    func requireJSON<Value: Decodable & Equatable>(
        _ expected: Value,
        as type: Value.Type = Value.self
    ) throws {
        let actual = try json(type)
        guard actual == expected else {
            throw TestFailure.json(
                reason: "Expected JSON \(String(describing: expected)), got \(String(describing: actual))"
            )
        }
    }
}

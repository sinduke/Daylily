import Daylily
import Foundation

enum DaylilyChecks {
    static func run() async throws {
        try await exactRoute()
        try await pathParameter()
        try await literalRouteBeatsParameterRoute()
        try await groupPrefix()
        try await jsonResponse()
        try await jsonBody()
        try await invalidJSONBody()
        try await notFound()

        print("Daylily checks passed.")
    }

    private static func exactRoute() async throws {
        let app = Application {
            Get("/hello") {
                "Daylily ships."
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/hello"))

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.bodyString == "Daylily ships.", "expected hello response")
    }

    private static func pathParameter() async throws {
        let app = Application {
            Get("/users/:id") { request in
                "User \(request.parameters.id ?? "unknown")"
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/users/42"))

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.bodyString == "User 42", "expected path parameter")
    }

    private static func literalRouteBeatsParameterRoute() async throws {
        let app = Application {
            Get("/users/:id") { request in
                "User \(request.parameters.id ?? "unknown")"
            }

            Get("/users/me") {
                "Current user"
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/users/me"))

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.bodyString == "Current user", "expected literal route to win")
    }

    private static func groupPrefix() async throws {
        let app = Application {
            Group("/api") {
                Get("/health") {
                    "ok"
                }
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/api/health"))

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.bodyString == "ok", "expected group route")
    }

    private static func jsonResponse() async throws {
        let app = Application {
            Get("/json/health") {
                JSON(HealthPayload(status: "ok"))
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/json/health"))
        let payload = try decodeJSON(HealthPayload.self, from: response)

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.headers["content-type"] == "application/json", "expected JSON content type")
        try expect(payload == HealthPayload(status: "ok"), "expected JSON health payload")
    }

    private static func jsonBody() async throws {
        let app = Application {
            Post("/json/echo") { request in
                let input = try request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }
        }

        let response = await app.respond(
            to: Request(
                method: .post,
                path: "/json/echo",
                headers: ["content-type": "application/json"],
                body: Array(#"{"message":"hi"}"#.utf8)
            )
        )
        let payload = try decodeJSON(EchoResponse.self, from: response)

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.headers["content-type"] == "application/json", "expected JSON content type")
        try expect(payload == EchoResponse(echo: "hi"), "expected echoed JSON body")
    }

    private static func invalidJSONBody() async throws {
        let app = Application {
            Post("/json/echo") { request in
                let input = try request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }
        }

        let response = await app.respond(
            to: Request(
                method: .post,
                path: "/json/echo",
                headers: ["content-type": "application/json"],
                body: Array("nope".utf8)
            )
        )

        try expect(response.status == .badRequest, "expected 400 Bad Request")
        try expect(response.bodyString == "Invalid JSON body", "expected invalid JSON body error")
    }

    private static func notFound() async throws {
        let app = Application {
            Get("/hello") {
                "Daylily ships."
            }
        }

        let response = await app.respond(to: Request(method: .get, path: "/missing"))

        try expect(response.status == .notFound, "expected 404 Not Found")
        try expect(response.bodyString == "Not Found", "expected not found body")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw CheckFailure(message: message)
        }
    }

    private static func decodeJSON<Value: Decodable>(_ type: Value.Type, from response: Response) throws -> Value {
        try JSONDecoder().decode(type, from: Data(response.body))
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let message: String

    var description: String {
        message
    }
}

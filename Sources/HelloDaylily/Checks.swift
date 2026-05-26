@_spi(Transport) import DaylilyCore
import Daylily
import Foundation

enum DaylilyChecks {
    static func run() async throws {
        try await exactRoute()
        try await pathParameter()
        try await literalRouteBeatsParameterRoute()
        try await groupPrefix()
        try await bodyBytes()
        try await bodyCollect()
        try await bodyCollectLimit()
        try await bodyStringHelper()
        try await streamingBodyChunksInOrder()
        try await streamingBodyFailure()
        try await streamingBodyCancellation()
        try await invalidUTF8Body()
        try await bodyOneShot()
        try await copiedBodyIsOneShot()
        try await jsonResponse()
        try await bodyJSON()
        try await jsonBody()
        try await invalidJSONBody()
        try await bodyLimitResponse()
        try await invalidUTF8Response()
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

    private static func bodyBytes() async throws {
        let body = Body.bytes(Array("hi".utf8))
        var chunks: [ByteChunk] = []

        for try await chunk in body.bytes {
            chunks.append(chunk)
        }

        try expect(chunks.count == 1, "expected one buffered byte chunk")
        try expect(chunks[0].bytes == Array("hi".utf8), "expected byte chunk bytes")
        try expect(chunks[0].count == 2, "expected byte chunk count")
    }

    private static func bodyCollect() async throws {
        let body = Body.bytes(Array("collect".utf8))
        let bytes = try await body.collect(upTo: .kilobytes(1))

        try expect(bytes == Array("collect".utf8), "expected collected body bytes")
    }

    private static func bodyCollectLimit() async throws {
        let body = Body.bytes(Array("toolarge".utf8))

        do {
            _ = try await body.collect(upTo: .bytes(2))
            try expect(false, "expected body too large error")
        } catch let error as BodyError {
            try expect(error.status == .payloadTooLarge, "expected 413 Payload Too Large")
            try expect(error.reason == "Request body too large", "expected body too large reason")
        }
    }

    private static func bodyStringHelper() async throws {
        let body = Body.bytes(Array("hello".utf8))
        let text = try await body.string(upTo: .kilobytes(1))

        try expect(text == "hello", "expected body string")
    }

    private static func streamingBodyChunksInOrder() async throws {
        let stream = Body.stream(bufferLimit: .bytes(2))
        let writer = stream.writer

        let producer = Task {
            await writer.write(ByteChunk(Array("ab".utf8)))
            await writer.write(ByteChunk(Array("cd".utf8)))
            await writer.finish()
        }

        var chunks: [[UInt8]] = []
        for try await chunk in stream.body.bytes {
            chunks.append(chunk.bytes)
        }

        await producer.value

        try expect(chunks == [Array("ab".utf8), Array("cd".utf8)], "expected streaming chunks in order")
    }

    private static func streamingBodyFailure() async throws {
        let stream = Body.stream()
        await stream.writer.fail()

        do {
            _ = try await stream.body.collect(upTo: .kilobytes(1))
            try expect(false, "expected stream failure")
        } catch let error as BodyError {
            try expect(error.status == .badRequest, "expected stream failure 400")
            try expect(error.reason == "Request body stream failed", "expected stream failure reason")
        }
    }

    private static func streamingBodyCancellation() async throws {
        let stream = Body.stream()
        let reader = Task {
            try await stream.body.collect(upTo: .kilobytes(1))
        }

        await stream.writer.cancel()
        let bytes = try await reader.value

        try expect(bytes.isEmpty, "expected cancelled stream to unblock reader")
    }

    private static func invalidUTF8Body() async throws {
        let body = Body.bytes([0xFF])

        do {
            _ = try await body.string(upTo: .kilobytes(1))
            try expect(false, "expected invalid UTF-8 body error")
        } catch let error as BodyError {
            try expect(error.status == .badRequest, "expected 400 Bad Request")
            try expect(error.reason == "Invalid UTF-8 body", "expected invalid UTF-8 reason")
        }
    }

    private static func bodyOneShot() async throws {
        let body = Body.bytes(Array("once".utf8))
        _ = try await body.collect(upTo: .kilobytes(1))

        do {
            _ = try await body.collect(upTo: .kilobytes(1))
            try expect(false, "expected already consumed error")
        } catch let error as BodyError {
            try expect(error.status == .internalServerError, "expected 500 Internal Server Error")
            try expect(error.reason == "Request body already consumed", "expected already consumed reason")
        }
    }

    private static func copiedBodyIsOneShot() async throws {
        let body = Body.bytes(Array("copy".utf8))
        let copy = body

        _ = try await body.collect(upTo: .kilobytes(1))

        do {
            _ = try await copy.collect(upTo: .kilobytes(1))
            try expect(false, "expected copied body to share one-shot state")
        } catch let error as BodyError {
            try expect(error.status == .internalServerError, "expected 500 Internal Server Error")
            try expect(error.reason == "Request body already consumed", "expected already consumed reason")
        }
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

    private static func bodyJSON() async throws {
        let body = Body.bytes(Array(#"{"message":"standard"}"#.utf8))
        let payload = try await body.json(EchoPayload.self, upTo: .megabytes(1))

        try expect(payload == EchoPayload(message: "standard"), "expected standard body JSON decode")
    }

    private static func jsonBody() async throws {
        let app = Application {
            Post("/json/echo") { request in
                let input = try await request.json(EchoPayload.self)
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
                let input = try await request.json(EchoPayload.self)
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

    private static func bodyLimitResponse() async throws {
        let app = Application {
            Post("/limited") { request in
                _ = try await request.body.collect(upTo: .bytes(2))
                return "ok"
            }
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/limited", body: Array("large".utf8))
        )

        try expect(response.status == .payloadTooLarge, "expected 413 Payload Too Large")
        try expect(response.bodyString == "Request body too large", "expected body too large response")
    }

    private static func invalidUTF8Response() async throws {
        let app = Application {
            Post("/utf8") { request in
                try await request.body.string(upTo: .kilobytes(1))
            }
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/utf8", body: [0xFF])
        )

        try expect(response.status == .badRequest, "expected 400 Bad Request")
        try expect(response.bodyString == "Invalid UTF-8 body", "expected invalid UTF-8 response")
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

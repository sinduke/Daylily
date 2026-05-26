@_spi(Transport) import DaylilyCore
import Daylily
import Foundation

enum DaylilyChecks {
    static func run() async throws {
        try await exactRoute()
        try await pathParameter()
        try await literalRouteBeatsParameterRoute()
        try await groupPrefix()
        try await middlewareOrder()
        try await middlewareSameScopeOrder()
        try await middlewareNestedGroupOrder()
        try await groupMiddlewareScope()
        try await applicationMiddlewareMissingRoute()
        try await middlewareShortCircuit()
        try await middlewareThrowing()
        try await middlewarePathParameters()
        try await middlewareBodyShortCircuit()
        try await middlewareBodyOneShot()
        try await requestWithBodyReplacement()
        try await withBufferedBodyMiddleware()
        try await withBufferedBodyReplacementIsOneShot()
        try await withBufferedBodyLimit()
        try await withBufferedBodyLimitResponse()
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

    private static func middlewareOrder() async throws {
        let log = EventLog()
        let app = Application {
            Group("/api") {
                Get("/users/:id") { request in
                    await log.append("handler:\(request.parameters.id ?? "missing")")
                    return "ok"
                }
                .middleware(RecordingMiddleware(name: "route", log: log))
            }
            .middleware(RecordingMiddleware(name: "group", log: log))
        }
        .middleware(RecordingMiddleware(name: "app", log: log))

        let response = await app.respond(to: Request(method: .get, path: "/api/users/42"))
        let events = await log.snapshot()

        try expect(response.status == .ok, "expected 200 OK")
        try expect(
            events == [
                "app before",
                "group before",
                "route before",
                "handler:42",
                "route after",
                "group after",
                "app after",
            ],
            "expected application -> group -> route -> handler middleware order"
        )
    }

    private static func middlewareSameScopeOrder() async throws {
        let log = EventLog()
        let app = Application {
            Get("/hello") {
                await log.append("handler")
                return "ok"
            }
            .middleware(RecordingMiddleware(name: "a", log: log))
            .middleware(RecordingMiddleware(name: "b", log: log))
        }

        let response = await app.respond(to: Request(method: .get, path: "/hello"))
        let events = await log.snapshot()

        try expect(response.status == .ok, "expected 200 OK")
        try expect(
            events == [
                "a before",
                "b before",
                "handler",
                "b after",
                "a after",
            ],
            "expected same-scope middleware declaration order"
        )
    }

    private static func middlewareNestedGroupOrder() async throws {
        let log = EventLog()
        let app = Application {
            Group("/outer") {
                Group("/inner") {
                    Get("/hello") {
                        await log.append("handler")
                        return "ok"
                    }
                    .middleware(RecordingMiddleware(name: "route", log: log))
                }
                .middleware(RecordingMiddleware(name: "inner", log: log))
            }
            .middleware(RecordingMiddleware(name: "outer", log: log))
        }

        let response = await app.respond(to: Request(method: .get, path: "/outer/inner/hello"))
        let events = await log.snapshot()

        try expect(response.status == .ok, "expected 200 OK")
        try expect(
            events == [
                "outer before",
                "inner before",
                "route before",
                "handler",
                "route after",
                "inner after",
                "outer after",
            ],
            "expected nested group middleware order"
        )
    }

    private static func groupMiddlewareScope() async throws {
        let app = Application {
            Group("/api") {
                Get("/health") {
                    "ok"
                }
            }
            .middleware(HeaderMiddleware(name: "x-scope", value: "group"))

            Get("/public") {
                "public"
            }
        }

        let grouped = await app.respond(to: Request(method: .get, path: "/api/health"))
        let publicRoute = await app.respond(to: Request(method: .get, path: "/public"))

        try expect(grouped.status == .ok, "expected grouped route 200 OK")
        try expect(grouped.headers["x-scope"] == "group", "expected group middleware header")
        try expect(publicRoute.status == .ok, "expected public route 200 OK")
        try expect(publicRoute.headers["x-scope"] == nil, "expected group middleware to stay scoped")
    }

    private static func applicationMiddlewareMissingRoute() async throws {
        let app = Application {
            Get("/hello") {
                "ok"
            }
        }
        .middleware(HeaderMiddleware(name: "x-app", value: "seen"))

        let response = await app.respond(to: Request(method: .get, path: "/missing"))

        try expect(response.status == .notFound, "expected 404 Not Found")
        try expect(response.bodyString == "Not Found", "expected not found body")
        try expect(response.headers["x-app"] == "seen", "expected application middleware to wrap 404")
    }

    private static func middlewareShortCircuit() async throws {
        let log = EventLog()
        let app = Application {
            Get("/protected") {
                await log.append("handler")
                return "secret"
            }
            .middleware(ShortCircuitMiddleware(log: log))
        }

        let response = await app.respond(to: Request(method: .get, path: "/protected"))
        let events = await log.snapshot()

        try expect(response.status == .badRequest, "expected short-circuit status")
        try expect(response.bodyString == "blocked", "expected short-circuit body")
        try expect(events == ["short-circuit"], "expected short-circuit to skip handler")
    }

    private static func middlewareThrowing() async throws {
        let app = Application {
            Get("/throws") {
                "unreachable"
            }
            .middleware(ThrowingMiddleware())
        }

        let response = await app.respond(to: Request(method: .get, path: "/throws"))

        try expect(response.status == .badRequest, "expected middleware error status")
        try expect(response.bodyString == "middleware failed", "expected middleware error body")
    }

    private static func middlewarePathParameters() async throws {
        let app = Application {
            Get("/users/:id") { request in
                "User \(request.parameters.id ?? "missing")"
            }
            .middleware(ParameterHeaderMiddleware())
        }

        let response = await app.respond(to: Request(method: .get, path: "/users/42"))

        try expect(response.status == .ok, "expected 200 OK")
        try expect(response.headers["x-user-id"] == "42", "expected middleware to see route parameters")
    }

    private static func middlewareBodyShortCircuit() async throws {
        let app = Application {
            Post("/body") {
                "unreachable"
            }
            .middleware(BodyEchoMiddleware())
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/body", body: Array("hello".utf8))
        )

        try expect(response.status == .ok, "expected body middleware 200 OK")
        try expect(response.bodyString == "middleware saw hello", "expected middleware to read body")
    }

    private static func middlewareBodyOneShot() async throws {
        let app = Application {
            Post("/body") { request in
                try await request.body.string(upTo: .kilobytes(1))
            }
            .middleware(BodyConsumingMiddleware())
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/body", body: Array("once".utf8))
        )

        try expect(response.status == .internalServerError, "expected consumed body 500 response")
        try expect(response.bodyString == "Request body already consumed", "expected consumed body reason")
    }

    private static func requestWithBodyReplacement() async throws {
        let request = Request(
            method: .post,
            path: "/replace",
            headers: ["x-original": "yes"],
            body: Array("old".utf8),
            parameters: Parameters(["id": "42"])
        )

        let replaced = request.with(body: .bytes(Array("new".utf8)))
        let body = try await replaced.body.string(upTo: .kilobytes(1))

        try expect(replaced.method == .post, "expected replacement to preserve method")
        try expect(replaced.path == "/replace", "expected replacement to preserve path")
        try expect(replaced.headers["x-original"] == "yes", "expected replacement to preserve headers")
        try expect(replaced.parameters.id == "42", "expected replacement to preserve parameters")
        try expect(body == "new", "expected replacement body")
    }

    private static func withBufferedBodyMiddleware() async throws {
        let app = Application {
            Post("/signed") { request in
                let body = try await request.body.string(upTo: .kilobytes(1))
                return "handler saw \(body)"
            }
            .middleware(BufferedBodyHeaderMiddleware())
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/signed", body: Array("signed".utf8))
        )

        try expect(response.status == .ok, "expected buffered middleware response")
        try expect(response.bodyString == "handler saw signed", "expected downstream body read")
        try expect(response.headers["x-buffered-body"] == "signed", "expected middleware to inspect bytes")
    }

    private static func withBufferedBodyReplacementIsOneShot() async throws {
        let request = Request(method: .post, path: "/body", body: Array("once".utf8))

        try await request.withBufferedBody(upTo: .kilobytes(1)) { replayedRequest, bytes in
            try expect(bytes == Array("once".utf8), "expected buffered body bytes")

            let firstRead = try await replayedRequest.body.string(upTo: .kilobytes(1))
            try expect(firstRead == "once", "expected first replacement body read")

            do {
                _ = try await replayedRequest.body.string(upTo: .kilobytes(1))
                try expect(false, "expected replacement body to be one-shot")
            } catch let error as BodyError {
                try expect(error.status == .internalServerError, "expected already consumed status")
                try expect(error.reason == "Request body already consumed", "expected already consumed reason")
            }
        }

        do {
            _ = try await request.body.string(upTo: .kilobytes(1))
            try expect(false, "expected original body to be consumed")
        } catch let error as BodyError {
            try expect(error.status == .internalServerError, "expected original body consumed status")
            try expect(error.reason == "Request body already consumed", "expected original body consumed reason")
        }
    }

    private static func withBufferedBodyLimit() async throws {
        let request = Request(method: .post, path: "/body", body: Array("large".utf8))

        do {
            try await request.withBufferedBody(upTo: .bytes(2)) { _, _ in
                try expect(false, "expected buffered body limit before closure")
            }
            try expect(false, "expected buffered body too large error")
        } catch let error as BodyError {
            try expect(error.status == .payloadTooLarge, "expected buffered body 413")
            try expect(error.reason == "Request body too large", "expected buffered body too large reason")
        }
    }

    private static func withBufferedBodyLimitResponse() async throws {
        let app = Application {
            Post("/signed") { request in
                try await request.withBufferedBody(upTo: .bytes(2)) { replayedRequest, _ in
                    try await replayedRequest.body.string(upTo: .kilobytes(1))
                }
            }
        }

        let response = await app.respond(
            to: Request(method: .post, path: "/signed", body: Array("large".utf8))
        )

        try expect(response.status == .payloadTooLarge, "expected buffered body limit response 413")
        try expect(response.bodyString == "Request body too large", "expected buffered body limit response")
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

private actor EventLog {
    private var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}

private struct RecordingMiddleware: Middleware {
    let name: String
    let log: EventLog

    func handle(_ request: Request, next: Handler) async throws -> Response {
        await log.append("\(name) before")
        let response = try await next.respond(to: request)
        await log.append("\(name) after")
        return response
    }
}

private struct HeaderMiddleware: Middleware {
    let name: String
    let value: String

    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers[name] = value
        return response
    }
}

private struct ShortCircuitMiddleware: Middleware {
    let log: EventLog

    func handle(_ request: Request, next: Handler) async throws -> Response {
        await log.append("short-circuit")
        return Response.text("blocked", status: .badRequest)
    }
}

private struct ThrowingMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        throw Abort(.badRequest, reason: "middleware failed")
    }
}

private struct ParameterHeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-user-id"] = request.parameters.id
        return response
    }
}

private struct BodyEchoMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        let body = try await request.body.string(upTo: .kilobytes(1))
        return Response.text("middleware saw \(body)")
    }
}

private struct BodyConsumingMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        _ = try await request.body.string(upTo: .kilobytes(1))
        return try await next.respond(to: request)
    }
}

private struct BufferedBodyHeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await request.withBufferedBody(upTo: .kilobytes(1)) { replayedRequest, bytes in
            var response = try await next.respond(to: replayedRequest)
            response.headers["x-buffered-body"] = String(decoding: bytes, as: UTF8.self)
            return response
        }
    }
}

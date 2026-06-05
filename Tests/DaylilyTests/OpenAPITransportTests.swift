import Daylily
import DaylilyOpenAPITransport
import HTTPTypes
import OpenAPIRuntime
import Testing

@Test("Daylily OpenAPI transport registers generated handlers as routes")
func daylilyOpenAPITransportRegistersGeneratedHandlersAsRoutes() async throws {
    let transport = DaylilyOpenAPITransport()

    try transport.register(
        { request, body, metadata in
            #expect(request.method.rawValue == "POST")
            #expect(request.path == "/pets/42?include=owner")
            #expect(metadata.pathParameters["petId"] == "42")
            let requestBody = try await String(collecting: body!, upTo: 1024)
            #expect(requestBody == "fluffy")

            var responseFields = HTTPFields()
            responseFields.append(HTTPField(name: .contentType, value: "text/plain"))
            responseFields.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: "a=1"))
            responseFields.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: "b=2"))

            return (
                HTTPResponse(status: HTTPResponse.Status(code: 202), headerFields: responseFields),
                HTTPBody("accepted:\(metadata.pathParameters["petId"] ?? "missing")")
            )
        },
        method: HTTPRequest.Method("POST")!,
        path: "/pets/{petId}"
    )

    let response = await transport.application().respond(
        to: Request(
            method: .post,
            path: "/pets/42?include=owner",
            headers: [
                "content-length": "6",
            ],
            body: .bytes(Array("fluffy".utf8))
        )
    )

    #expect(response.status.code == 202)
    #expect(response.headers["content-type"] == "text/plain")
    #expect(response.headers.values(for: "set-cookie") == ["a=1", "b=2"])
    #expect(response.bodyString == "accepted:42")
}

@Test("Daylily OpenAPI transport rejects unsupported path templates")
func daylilyOpenAPITransportRejectsUnsupportedPathTemplates() throws {
    let transport = DaylilyOpenAPITransport()

    try expectOpenAPITransportError(.unsupportedPathTemplate("/files/{name}.zip")) {
        try transport.register(
            { _, _, _ in
                (HTTPResponse(status: HTTPResponse.Status(code: 200)), nil)
            },
            method: HTTPRequest.Method("GET")!,
            path: "/files/{name}.zip"
        )
    }

    try expectOpenAPITransportError(.duplicatePathParameter("id")) {
        try transport.register(
            { _, _, _ in
                (HTTPResponse(status: HTTPResponse.Status(code: 200)), nil)
            },
            method: HTTPRequest.Method("GET")!,
            path: "/parents/{id}/children/{id}"
        )
    }
}

private func expectOpenAPITransportError(
    _ expected: DaylilyOpenAPITransportError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
        Issue.record("Expected \(expected)")
    } catch let error as DaylilyOpenAPITransportError {
        #expect(error == expected)
    }
}

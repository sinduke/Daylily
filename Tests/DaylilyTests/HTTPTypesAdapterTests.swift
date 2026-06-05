import Daylily
import DaylilyHTTPTypes
import HTTPTypes
import Testing

@Test("Swift HTTP Types request adapter preserves HTTP boundary")
func swiftHTTPTypesRequestAdapterPreservesHTTPBoundary() throws {
    var headerFields = HTTPFields()
    var traceField = HTTPField(name: HTTPField.Name("X-Trace")!, value: "first")
    traceField.indexingStrategy = .avoid
    headerFields.append(traceField)
    headerFields.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: "a=1"))
    headerFields.append(HTTPField(name: HTTPField.Name("set-cookie")!, value: "b=2"))

    var httpRequest = HTTPRequest(
        method: HTTPRequest.Method("PROPFIND")!,
        scheme: "https",
        authority: "api.example.com",
        path: "/items?tag=tea&flag&tag=oolong",
        headerFields: headerFields
    )
    httpRequest.extendedConnectProtocol = "websocket"

    let request = Request(httpTypesRequest: httpRequest)
    let roundTripped = try request.httpTypesRequest()

    #expect(request.method.rawValue == "PROPFIND")
    #expect(request.rawTarget == "/items?tag=tea&flag&tag=oolong")
    #expect(request.path == "/items")
    #expect(request.query.values(for: "tag") == ["tea", "oolong"])
    #expect(request.query.parameters[1].hasValue == false)
    #expect(request.scheme == "https")
    #expect(request.authority == "api.example.com")
    #expect(request.extendedConnectProtocol == "websocket")
    #expect(request.headers.values(for: "set-cookie") == ["a=1", "b=2"])
    #expect(request.headers.fields[0].indexingStrategy == .avoid)

    #expect(roundTripped.method.rawValue == httpRequest.method.rawValue)
    #expect(roundTripped.scheme == httpRequest.scheme)
    #expect(roundTripped.authority == httpRequest.authority)
    #expect(roundTripped.path == httpRequest.path)
    #expect(roundTripped.extendedConnectProtocol == httpRequest.extendedConnectProtocol)
    #expect(headerLines(roundTripped.headerFields) == headerLines(httpRequest.headerFields))
    #expect(roundTripped.headerFields.first?.indexingStrategy == .avoid)
}

@Test("Swift HTTP Types response adapter preserves status and repeated headers")
func swiftHTTPTypesResponseAdapterPreservesStatusAndRepeatedHeaders() throws {
    var headerFields = HTTPFields()
    headerFields.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: "a=1"))
    headerFields.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: "b=2"))

    let httpResponse = HTTPResponse(
        status: HTTPResponse.Status(code: 299, reasonPhrase: "Custom OK"),
        headerFields: headerFields
    )

    let response = Response(httpTypesResponse: httpResponse, body: Array("done".utf8))
    let roundTripped = try response.httpTypesResponse()

    #expect(response.status.code == 299)
    #expect(response.status.reasonPhrase == "Custom OK")
    #expect(response.headers.values(for: "set-cookie") == ["a=1", "b=2"])
    #expect(response.bodyString == "done")
    #expect(roundTripped.status.code == 299)
    #expect(roundTripped.status.reasonPhrase == "Custom OK")
    #expect(headerLines(roundTripped.headerFields) == headerLines(httpResponse.headerFields))
}

@Test("Swift HTTP Types adapter rejects lossy conversions")
func swiftHTTPTypesAdapterRejectsLossyConversions() throws {
    try expectHTTPTypesError(.invalidHeaderName("bad header")) {
        _ = try Headers(fields: [(name: "bad header", value: "value")]).httpTypesHeaderFields()
    }

    try expectHTTPTypesError(.invalidHeaderValue(name: "x-bad", value: " leading")) {
        _ = try Headers(fields: [(name: "x-bad", value: " leading")]).httpTypesHeaderFields()
    }

    try expectHTTPTypesError(.invalidStatusCode(1_000)) {
        _ = try Response(status: Status(1_000, reasonPhrase: "Invalid")).httpTypesResponse()
    }

    try expectHTTPTypesError(.invalidReasonPhrase("bad\nreason")) {
        _ = try Response(status: Status(599, reasonPhrase: "bad\nreason")).httpTypesResponse()
    }
}

private func headerLines(_ fields: HTTPFields) -> [String] {
    fields.map { "\($0.name.rawName): \($0.value)" }
}

private func expectHTTPTypesError(
    _ expected: DaylilyHTTPTypesError,
    operation: () throws -> Void
) throws {
    do {
        try operation()
        Issue.record("Expected \(expected)")
    } catch let error as DaylilyHTTPTypesError {
        #expect(error == expected)
    }
}

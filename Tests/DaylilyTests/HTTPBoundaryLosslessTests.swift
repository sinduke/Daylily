import Daylily
import Testing

@Test("Headers preserve repeated fields and original order")
func headersPreserveRepeatedFieldsAndOriginalOrder() {
    var headers = Headers()
    headers.add(name: "Set-Cookie", value: "a=1")
    headers.add(name: "X-Trace", value: "first")
    headers.add(name: "set-cookie", value: "b=2")
    headers["X-Trace"] = "second"

    #expect(headers.all.map { "\($0.name): \($0.value)" } == [
        "Set-Cookie: a=1",
        "X-Trace: second",
        "set-cookie: b=2",
    ])
    #expect(headers.values(for: "SET-COOKIE") == ["a=1", "b=2"])
    #expect(headers["set-cookie"] == "b=2")
}

@Test("Request preserves raw target and repeated query parameters")
func requestPreservesRawTargetAndRepeatedQueryParameters() {
    let request = Request(
        method: HTTPMethod("PROPFIND")!,
        path: "/search?tag=tea&flag&tag=oolong&empty=&term=daylily+ships"
    )

    #expect(request.method.rawValue == "PROPFIND")
    #expect(request.rawTarget == "/search?tag=tea&flag&tag=oolong&empty=&term=daylily+ships")
    #expect(request.target == "/search?tag=tea&flag&tag=oolong&empty=&term=daylily+ships")
    #expect(request.path == "/search")
    #expect(request.query.rawValue == "tag=tea&flag&tag=oolong&empty=&term=daylily+ships")
    #expect(request.query.all.map { "\($0.name): \($0.value)" } == [
        "tag: tea",
        "flag: ",
        "tag: oolong",
        "empty: ",
        "term: daylily ships",
    ])
    #expect(request.query.parameters.map(\.hasValue) == [true, false, true, true, true])
    #expect(request.query.values(for: "tag") == ["tea", "oolong"])
    #expect(request.query["tag"] == "oolong")
}

@Test("Request with operations preserve raw target and pseudo fields")
func requestWithOperationsPreserveBoundaryMetadata() {
    let request = Request(
        method: .connect,
        rawTarget: nil,
        scheme: "https",
        authority: "example.com",
        extendedConnectProtocol: "websocket",
        headers: ["x-original": "yes"]
    )

    let replaced = request
        .with(headers: ["x-replaced": "yes"])
        .with(parameters: Parameters(["id": "42"]))
        .with(dependencies: Dependencies())

    #expect(replaced.rawTarget == nil)
    #expect(replaced.path == "/")
    #expect(replaced.scheme == "https")
    #expect(replaced.authority == "example.com")
    #expect(replaced.extendedConnectProtocol == "websocket")
    #expect(replaced.headers["x-replaced"] == "yes")
    #expect(replaced.parameters.id == "42")
}

# Testing Example

`DaylilyTesting` lets tests exercise the same in-memory runtime behavior without opening a socket.

## Basic Request

```swift
import Daylily
import DaylilyTesting

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}

let response = try await TestClient(app).get("/hello")

try response.requireStatus(.ok)
try response.requireBody("Daylily ships.")
```

## JSON Request and Response

```swift
struct EchoPayload: Codable, Equatable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Equatable, Sendable {
    let echo: String
}

let app = Application {
    Post("/json/echo") { request in
        let input = try await request.json(EchoPayload.self)
        return JSON(EchoResponse(echo: input.message))
    }
}

let request = try TestRequest
    .post("/json/echo")
    .withJSON(EchoPayload(message: "hi"))

let response = try await TestClient(app).send(request)

try response.requireStatus(.ok)
try response.requireJSON(EchoResponse(echo: "hi"))
```

## Request Builders

`TestRequest` includes builders for all implemented HTTP verbs:

```swift
let putRequest = TestRequest
    .put("/users/42")
    .withBody("full")

let patchRequest = TestRequest
    .patch("/users/42")
    .withHeader("x-daylily", "ships")
    .withBody("partial")
```

## Shared Check Suite

The repository also ships a shared behavior check suite:

```sh
swift run HelloDaylily --check
swift test
```

The formal Swift Testing target calls the same check suite, so local tests and the executable smoke check stay aligned.

# 01 Add an endpoint

Starting point: `AddEndpoint.application()` contains only:

```swift
Application {
    Get("/health") { "ok" }
}
```

Request: add `GET /greetings/:name`, returning `Hello, <name>!`. Keep health working.
Use typed path extraction and describe the path input and text response in runtime
metadata, with operation ID `greet`.

Acceptance:

- `GET /health` is still 200 with body `ok`.
- `GET /greetings/Ada` is 200 with body `Hello, Ada!`; `/greetings` is 404.
- Validated OpenAPI includes `/greetings/{name}`, required string path parameter
  `name`, operation ID `greet`, and a 200 `text/plain` string response.

Completed reference: `Sources/ApplicationExercises/AddEndpoint.swift`.
Executable checks: `AddEndpointAcceptance` (2 tests).

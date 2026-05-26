# 0011 DaylilyTesting

Status: proposed

Purpose:

- Replace ad hoc executable checks with a first-class testing experience.
- Make Daylily easy for humans and AI agents to verify.
- Provide stable in-memory request/response tooling for future features.

Target experience:

```swift
let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}

let response = try await TestClient(app).get("/hello")

#expect(response.status == .ok)
#expect(response.bodyString == "Daylily ships.")
```

Recommended tasks:

- `0011-001-minimal-test-client`
- `0011-002-request-builders-and-json-assertions`

Timing:

- Start after `0010-001` and `0010-002` if typed path inputs are moving smoothly.
- Do not wait until all typed handler inputs are done.

Design notes:

- Testing is part of Daylily's AI-native identity.
- `TestClient` should use `Application.respond(to:)` directly.
- Keep the first version transport-free.
- Keep checks fast and deterministic.

Non-goals for the first task:

- Real network test server.
- Browser testing.
- Load testing.
- Snapshot testing.
- Full Swift Testing migration if it slows down the core loop.

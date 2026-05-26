# 0011-002 Request Builders and JSON Assertions

Status: implemented
Epic: 0011-daylily-testing

Goal:

- Extend `DaylilyTesting` beyond minimal verb helpers.
- Add a small `TestRequest` builder for in-memory requests.
- Add JSON response decoding and throwing assertion helpers.
- Keep testing support transport-free and NIO-free.

Scope:

- Add public `TestRequest`.
- Add `TestClient.send(_:)`.
- Add `TestClient.postJSON(_:headers:body:)`.
- Add response helpers:
  - `json(_:)`
  - `requireStatus(_:)`
  - `requireBody(_:)`
  - `requireJSON(_:as:)`
- Add public `TestFailure` for failed testing assertions.
- Add behavior checks through `HelloDaylily --check`.
- Update README and AIDEV docs.

Non-goals:

- Dedicated Swift test target.
- XCTest or Swift Testing integration.
- Snapshot testing.
- Real network test server.
- Coupling `DaylilyTesting` to NIO.
- Moving runtime JSON helpers into `DaylilyCore`.

Target usage:

```swift
let request = try TestRequest
    .post("/json/echo")
    .withJSON(EchoPayload(message: "hi"))

let response = try await TestClient(app).send(request)

try response.requireStatus(.ok)
try response.requireJSON(EchoResponse(echo: "hi"))
```

Design rules:

- `DaylilyTesting` may use Foundation JSON encoding/decoding for test helpers.
- `DaylilyTesting` must not import NIO.
- `TestRequest` is a convenience builder for Daylily `Request` values.
- `TestRequest.toRequest()` is the bridge back to runtime types.
- `TestClient` continues to call `Application.respond(to:)` directly.
- Testing JSON helpers are assertions and decoding aids; runtime JSON behavior remains owned by `DaylilyJSON`.
- Request bodies are still one-shot once sent.

Steps:

- [x] 0011-002.1 Add `TestRequest`.
- [x] 0011-002.2 Add `TestClient.send(_:)` and `postJSON`.
- [x] 0011-002.3 Add response JSON and assertion helpers.
- [x] 0011-002.4 Add behavior checks.
- [x] 0011-002.5 Update README and AIDEV docs.
- [x] 0011-002.6 Review, fix, validate, then finish the task.

Architecture impact:

- Expands `DaylilyTesting` while keeping it transport-free.
- Adds Foundation to testing helpers for JSON encode/decode.
- Does not change runtime routing, middleware, body, JSON, macro, or NIO behavior.

Public API impact:

- Adds `TestRequest`.
- Adds `TestFailure`.
- Adds `TestClient.send(_:)`.
- Adds `TestClient.postJSON(_:headers:body:)`.
- Adds `Response` testing helper extensions in `DaylilyTesting`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/concepts.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0011-daylily-testing.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Completed validation:

```sh
swift build
swift run HelloDaylily --check
if rg -n "NIO" Sources/DaylilyTesting; then exit 1; else echo "DaylilyTesting NIO-free"; fi
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- `TestRequest.post(...).withBody(...)` sends body bytes.
- `TestRequest.withHeader(...)` preserves headers.
- `TestClient.postJSON(..., body:)` encodes JSON and sets `content-type`.
- `Response.json(_:)` decodes JSON responses.
- `Response.requireStatus(_:)`, `requireBody(_:)`, and `requireJSON(_:)` throw clear `TestFailure` values.
- `DaylilyTesting` remains NIO-free.
- `registry.yml` parses.
- `git diff --check` passes.

Notes:

- This completes the first DaylilyTesting slice. A dedicated Swift test target can be added later once the project chooses XCTest or Swift Testing.

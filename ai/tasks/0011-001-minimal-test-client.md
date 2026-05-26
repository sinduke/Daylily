# 0011-001 Minimal Test Client

Status: implemented
Epic: 0011-daylily-testing

Goal:

- Add the first DaylilyTesting surface.
- Provide a transport-free `TestClient` for in-memory request/response checks.
- Make future framework behavior easier for humans and AI agents to verify.

Scope:

- Add a `DaylilyTesting` library product.
- Add a `DaylilyTesting` target that depends on `DaylilyCore`.
- Add public `TestClient`.
- Let `TestClient` call `Application.respond(to:)` directly.
- Support minimal request helpers:
  - `respond(to:)`
  - `get(_:)`
  - `post(_:body:)`
- Add behavior checks through `HelloDaylily --check`.
- Update AIDEV documentation, README examples, roadmap, and registry.

Non-goals:

- Real network test server.
- Browser testing.
- Load testing.
- Snapshot testing.
- Swift Testing or XCTest migration.
- JSON assertion helpers.
- Rich request builder DSL.

Target usage:

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

Design rules:

- `TestClient` is not a transport.
- `TestClient` must not depend on NIO.
- `TestClient` should reuse `Request`, `Response`, `Headers`, `Body`, and `Application`.
- `Application.respond(to:)` remains the authoritative in-memory behavior surface.

Steps:

- [x] 0011-001.1 Add `DaylilyTesting` product and target.
- [x] 0011-001.2 Implement minimal `TestClient`.
- [x] 0011-001.3 Add behavior checks.
- [x] 0011-001.4 Update README and AIDEV docs.
- [x] 0011-001.5 Update registry and roadmap.
- [x] 0011-001.6 Review, fix, validate, then finish the task.

Architecture impact:

- Adds a testing helper module outside `DaylilyCore`.
- Keeps testing helpers transport-free.
- Does not change runtime routing, middleware, body, JSON, or macro behavior.

Public API impact:

- Adds `DaylilyTesting` product.
- Adds `TestClient`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/architecture.md`
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

- `TestClient(app).get("/hello")` returns a response.
- `TestClient(app).post(..., body: "hi")` sends request body bytes.
- Missing route behavior matches `Application.respond(to:)`.
- `DaylilyTesting` does not depend on NIO.
- `registry.yml` parses.
- `git diff --check` passes.

Notes:

- This task is intentionally small. Rich request builders and JSON assertions belong in `0011-002`.

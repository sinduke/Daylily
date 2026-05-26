# 0015-001 Runtime And Testing HTTP Verbs

Status: implemented
Epic: 0015-http-verbs-beta-closure

Goal:

- Complete runtime and testing support for beta HTTP verbs.
- Make handwritten Daylily routes support `PUT`, `PATCH`, `DELETE`, `HEAD`, and `OPTIONS`.
- Make `DaylilyTesting` ergonomic for the same verbs.

Scope:

- Add `HEAD` and `OPTIONS` to `HTTPMethod`.
- Keep existing `PUT`, `PATCH`, and `DELETE` method cases.
- Add runtime route DSL functions:
  - `Put`
  - `Patch`
  - `Delete`
  - `Head`
  - `Options`
- Add zero-parameter and `Request` handler overloads for each new runtime DSL function.
- Add `TestClient` helpers for:
  - `put`
  - `patch`
  - `delete`
  - `head`
  - `options`
- Add `TestRequest` builders for:
  - `put`
  - `patch`
  - `delete`
  - `head`
  - `options`
- Add behavior checks for runtime routing and testing helpers.
- Add example routes to `HelloDaylily`.
- Update README and AIDEV docs.

Non-goals:

- Route macros for the new verbs.
- `@PUT`, `@PATCH`, `@DELETE`, `@HEAD`, or `@OPTIONS`.
- Macro smoke tests for the new verbs.
- Automatic `HEAD -> GET` fallback.
- Automatic `OPTIONS Allow` responses.
- Automatic CORS preflight behavior.
- Special default response for `DELETE`.
- New status constants; `Status.noContent` already exists.

Rules:

- Runtime APIs are the source of truth.
- Macro support is deferred to `0015-002`.
- `HEAD` and `OPTIONS` are explicit route methods only in this task.
- `DELETE` handlers should return whatever the user chooses; examples may use `.noContent`.
- `DaylilyCore` must stay free of Foundation and NIO imports.
- NIO transport method mapping should work through `HTTPMethod(head.method.rawValue)`.

Target usage:

```swift
let app = Application {
    Put("/users/:id") { request in
        "updated"
    }

    Patch("/users/:id") { request in
        "patched"
    }

    Delete("/users/:id") {
        Status.noContent
    }

    Head("/health") {
        Status.ok
    }

    Options("/health") {
        Status.noContent
    }
}
```

Testing target usage:

```swift
let client = TestClient(app)

try await client.put("/users/1", body: "updated")
try await client.patch("/users/1", body: "patched")
try await client.delete("/users/1")
try await client.head("/health")
try await client.options("/health")
```

Steps:

- [x] 0015-001.1 Add missing `HTTPMethod` cases.
- [x] 0015-001.2 Add runtime DSL functions.
- [x] 0015-001.3 Add `DaylilyTesting` helpers.
- [x] 0015-001.4 Add behavior checks and example routes.
- [x] 0015-001.5 Update README and AIDEV docs.
- [x] 0015-001.6 Review, fix, validate, then finish the task.

Architecture impact:

- Extends the existing runtime route DSL without changing router behavior.
- Keeps method routing based on `HTTPMethod`.
- Keeps NIO-specific method parsing in `DaylilyNIO`.
- Keeps macro and OpenAPI expansion as the next task.

Public API impact:

- Adds `HTTPMethod.head`.
- Adds `HTTPMethod.options`.
- Adds `Put`, `Patch`, `Delete`, `Head`, and `Options` runtime DSL functions.
- Adds `TestClient` helpers for new verbs.
- Adds `TestRequest` builders for new verbs.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/project-map.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/extension-playbooks.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0015-http-verbs-beta-closure.md`

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
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
rg -n "^(import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix)|@_exported import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix))" Sources/DaylilyCore || true
```

Suggested additional checks:

- `registry.yml` parses.
- `git diff --check` passes.
- `DaylilyCore` does not import Foundation or NIO.
- Runtime routes match each new verb.
- Wrong method on the same path stays `404`.
- `DELETE` can return `.noContent`.
- `TestClient` helpers send the expected methods.
- `TestRequest` builders preserve body/header behavior where applicable.

Notes:

- `Status.noContent` already exists before this task.
- `PUT`, `PATCH`, and `DELETE` already exist in `HTTPMethod` before this task, but their runtime DSL/testing surface is incomplete.
- `HEAD` response body suppression is not introduced in this task; this task only makes `HEAD` an explicit route method.

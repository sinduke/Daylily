# 0015-002 Macro And OpenAPI HTTP Verbs

Status: implemented
Epic: 0015-http-verbs-beta-closure

Goal:

- Complete the macro and OpenAPI side of the beta HTTP verbs loop.
- Let macro route declarations use the same supported verbs as the runtime DSL.
- Verify OpenAPI output includes the expanded HTTP method set.

Scope:

- Add public route marker macros:
  - `@PUT`
  - `@PATCH`
  - `@DELETE`
  - `@HEAD`
  - `@OPTIONS`
- Extend `@DaylilyServer` route collection to recognize the new marker macros.
- Lower new marker macros into runtime DSL functions:
  - `@PUT` -> `Put`
  - `@PATCH` -> `Patch`
  - `@DELETE` -> `Delete`
  - `@HEAD` -> `Head`
  - `@OPTIONS` -> `Options`
- Update macro diagnostics that still mention only `@GET` and `@POST`.
- Add macro smoke coverage for top-level and grouped new verb handlers.
- Add OpenAPI behavior checks for `put`, `patch`, `delete`, `head`, and `options` output keys.
- Update README and AIDEV docs.

Non-goals:

- Runtime DSL changes; delivered by `0015-001`.
- New OpenAPI DTO fields.
- OpenAPI security, tags, summaries, or response inference beyond existing metadata.
- Automatic `HEAD -> GET` fallback.
- Automatic `OPTIONS Allow` responses.
- Automatic CORS preflight behavior.
- `@Body` spelling.
- Dedicated Swift test target.

Rules:

- Macros must lower into the runtime DSL.
- Runtime route metadata remains the OpenAPI source of truth.
- `DaylilyOpenAPI` should continue reading `Application.describeRoutes()`.
- No macro-only metadata system is allowed.
- `HEAD` and `OPTIONS` remain explicit route methods only.

Target usage:

```swift
@DaylilyServer
struct App {
    @PUT("/users/:id")
    func update(@Path id: Int, req: Request) async throws -> String {
        "updated"
    }

    @PATCH("/users/:id")
    func patch(@Path id: Int, req: Request) async throws -> String {
        "patched"
    }

    @DELETE("/users/:id")
    func delete(@Path id: Int) -> Status {
        .noContent
    }

    @HEAD("/health")
    func head() -> Status {
        .ok
    }

    @OPTIONS("/health")
    func options() -> Status {
        .noContent
    }
}
```

Steps:

- [x] 0015-002.1 Add public marker macros.
- [x] 0015-002.2 Extend macro route collection/lowering.
- [x] 0015-002.3 Add macro smoke coverage.
- [x] 0015-002.4 Add OpenAPI method output checks.
- [x] 0015-002.5 Update README and AIDEV docs.
- [x] 0015-002.6 Review, fix, validate, then finish the task.

Architecture impact:

- Extends macro sugar over existing runtime DSL.
- Keeps OpenAPI generation runtime-metadata driven.
- Keeps `DaylilyCore` independent from macro implementation details.

Public API impact:

- Adds `@PUT`.
- Adds `@PATCH`.
- Adds `@DELETE`.
- Adds `@HEAD`.
- Adds `@OPTIONS`.

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

Suggested additional checks:

- `registry.yml` parses.
- `git diff --check` passes.
- Macro smoke routes compile for all new verb attributes.
- OpenAPI document output contains `put`, `patch`, `delete`, `head`, and `options`.
- Macro-generated typed inputs still lower into route metadata.

Notes:

- OpenAPI already maps `RouteDescription.method.rawValue.lowercased()` into path method keys; this task adds explicit coverage for the expanded method set.
- `0015-001` intentionally left macro support for this task.

Completed validation:

```sh
swift build
swift run HelloDaylily --check
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
rg -n '^(import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix)|@_exported import (Foundation|NIO|NIOCore|NIOHTTP1|NIOPosix))' Sources/DaylilyCore || true
swift build -Xswiftc -Xfrontend -Xswiftc -dump-macro-expansions 2>&1 | rg -n 'Put\("/macro|Patch\("/macro|Delete\("/macro|Head\("/macro|Options\("/macro'
```

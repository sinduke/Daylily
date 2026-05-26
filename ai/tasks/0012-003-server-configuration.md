# 0012-003 Server Configuration

Status: implemented
Epic: 0012-lifecycle-server-controls

Goal:

- Add explicit server controls before production-oriented features expand.
- Keep user-facing server configuration NIO-free.
- Preserve the existing `run(host:port:)` convenience.

Scope:

- Add `ServerConfiguration` in `DaylilyCore`.
- Add `Application.run(configuration:)`.
- Extend `NIOServerConfiguration`.
- Bridge `ServerConfiguration` into `NIOServerConfiguration`.
- Wire backlog, address reuse, max messages per read, and graceful shutdown signal handling.
- Add behavior checks.
- Update README and AIDEV docs.

Non-goals:

- TLS.
- HTTP/2.
- Worker thread count.
- Request timeout controls.
- Connection draining controls.
- Deployment platform presets.

Target usage:

```swift
try await app.run(
    configuration: ServerConfiguration(
        host: "0.0.0.0",
        port: 8080,
        backlog: 256,
        reuseAddress: true,
        maxMessagesPerRead: 16,
        gracefulShutdownSignals: true
    )
)
```

Rules:

- `ServerConfiguration` lives in `DaylilyCore`.
- `Application.run(host:port:)` remains available.
- `Application.run(configuration:)` is the explicit server control surface.
- `NIOServerConfiguration` mirrors current NIO transport controls.
- Defaults preserve existing behavior.

Steps:

- [x] 0012-003.1 Add public `ServerConfiguration`.
- [x] 0012-003.2 Add `Application.run(configuration:)`.
- [x] 0012-003.3 Extend NIO transport configuration.
- [x] 0012-003.4 Add checks.
- [x] 0012-003.5 Update README and AIDEV docs.
- [x] 0012-003.6 Review, fix, validate, then finish the task.

Architecture impact:

- Adds a NIO-free configuration type in `DaylilyCore`.
- Keeps NIO-specific application inside `DaylilyNIO`.
- Makes production controls explicit without broadening ecosystem scope.

Public API impact:

- Adds `ServerConfiguration`.
- Adds `Application.run(configuration:)`.
- Extends `NIOServerConfiguration`.

AIDEV updates required:

- `README.md`
- `README.zh-CN.md`
- `ai/aidev/start-here.md`
- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/project-map.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0012-lifecycle-server-controls.md`

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
```

Suggested checks:

- `ServerConfiguration()` preserves defaults.
- Custom `ServerConfiguration` bridges into `NIOServerConfiguration`.
- Existing `run(host:port:)` still compiles.
- `registry.yml` parses.
- `git diff --check` passes.

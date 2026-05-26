# 0012-001 Application Lifecycle MVP

Status: implemented
Epic: 0012-lifecycle-server-controls

Goal:

- Add runtime lifecycle hooks before ecosystem modules.
- Create explicit mounting points for future resources such as database pools, Redis clients, workers, and graceful shutdown.
- Keep lifecycle transport-neutral in `DaylilyCore`.

Scope:

- Add `LifecyclePhase`.
- Add `LifecycleOperation`.
- Let `Application` register lifecycle hooks.
- Add convenience hook methods:
  - `configure`
  - `boot`
  - `started`
  - `shutdown`
  - `cleanup`
- Add `Application.runLifecycle(_:)`.
- Integrate `Application.run` with lifecycle order.
- Add `NIOHTTPServer.run(started:)` so `started` runs after bind succeeds.
- Add behavior checks.
- Update README and AIDEV docs.

Non-goals:

- Signal handling.
- Graceful request draining.
- Server worker/backlog configuration.
- Database, Redis, or job worker integrations.
- Dependency injection.

Target usage:

```swift
let app = Application {
    Get("/hello") { "ok" }
}
.configure {
    ...
}
.boot {
    ...
}
.started {
    ...
}
.shutdown {
    ...
}
.cleanup {
    ...
}
```

Lifecycle order in `Application.run`:

```text
configure -> boot -> NIO bind -> started -> server close -> shutdown -> cleanup
```

Rules:

- Hooks run in registration order within each phase.
- `configure` and `boot` run before server bind.
- `started` runs after NIO bind succeeds.
- `shutdown` and `cleanup` are attempted if server run fails after boot.
- `Application.respond(to:)` does not run lifecycle hooks.
- Lifecycle hooks are async and throwing.
- Lifecycle does not expose NIO types.

Steps:

- [x] 0012-001.1 Add lifecycle phase model.
- [x] 0012-001.2 Add hook registration on `Application`.
- [x] 0012-001.3 Add lifecycle execution API.
- [x] 0012-001.4 Integrate `Application.run`.
- [x] 0012-001.5 Add checks.
- [x] 0012-001.6 Update README and AIDEV docs.
- [x] 0012-001.7 Review, fix, validate, then finish the task.

Architecture impact:

- Expands `DaylilyCore` with runtime lifecycle concepts.
- Keeps transport integration in `Daylily` / `DaylilyNIO`.
- Creates future extension points without adding ecosystem modules.

Public API impact:

- Adds `LifecycleOperation`.
- Adds `LifecyclePhase`.
- Adds `Application.lifecycle(_:_: )`.
- Adds `Application.configure(_:)`.
- Adds `Application.boot(_:)`.
- Adds `Application.started(_:)`.
- Adds `Application.shutdown(_:)`.
- Adds `Application.cleanup(_:)`.
- Adds `Application.runLifecycle(_:)`.
- Adds `NIOHTTPServer.run(started:)`.

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

- Lifecycle hooks run in phase order when phases are invoked.
- Multiple hooks in a phase preserve registration order.
- Thrown lifecycle errors propagate.
- `Application.run` invokes `started` after NIO bind.
- `registry.yml` parses.
- `git diff --check` passes.

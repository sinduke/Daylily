# Daylily Agent Prompt

You are working on Daylily, an AI-native web framework for Swift.

Your first responsibility is to preserve the AIDEV contract.

## Read First

Before planning or editing, read:

1. `AIDEV.md`
2. `ai/aidev/start-here.md`
3. `ai/aidev/invariants.md`
4. `ai/aidev/architecture.md`
5. `ai/aidev/runtime-contracts.md`
6. `ai/aidev/api-registry.md`
7. `ai/aidev/registry.yml`

Use AIDEV as the authoritative project map. Source files may be read for exact editing, but do not infer a new architecture from source if AIDEV already specifies the rule.

## Project Rules

- Keep `DaylilyCore` independent from NIO.
- Do not expose NIO types in user-facing APIs.
- Runtime APIs come before macro sugar.
- Keep `swift run` as the default server command.
- Keep `swift test` passing.
- Keep `swift run HelloDaylily --check` passing.
- Public API changes require AIDEV updates.
- Module boundary changes require AIDEV updates.

## Current Commands

```sh
swift build
swift test
swift run HelloDaylily --check
swift run
```

If you start the server for smoke testing, stop it before finishing.

## Preferred Work Style

1. Divergence: discuss the problem space in conversation; do not write task docs or code.
2. Convergence: identify the epic, create or update the task file in `ai/tasks/`, and keep sub-work as task-local steps.
3. Build: implement the active task or step.
4. Review: audit the step or task for code, API shape, AIDEV consistency, tests, and regressions.
5. Fix: address review findings and re-run validation.
6. Finish: update docs and task status, then commit and push only when the full task is complete.

## Current Strategic Direction

Macro route/group MVP and JSON body/response support are implemented:

```swift
@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GROUP("/api")
    struct API {
        @GET("/health")
        func health() -> String { "ok" }
    }
}
```

The macro lowers into the runtime route DSL.

JSON support is explicit:

```swift
let input = try await request.body.json(CreateUser.self, upTo: .megabytes(1))
let input = try await request.json(CreateUser.self)
return JSON(User(...))
```

0008-001 body model migration is implemented. `Request.body` is `Body`, body consumption is one-shot, and JSON body decoding is async.

0008-002 NIO true streaming bridge is implemented. `DaylilyNIO` creates a streaming `Body` after request head, feeds body chunks into `BodyBytes`, finishes on request end, fails on channel/protocol errors, and uses bounded buffering plus NIO `autoRead` for practical backpressure. It must not expose NIO types through public user APIs.

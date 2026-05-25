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
- Keep `swift run HelloDaylily --check` passing.
- Public API changes require AIDEV updates.
- Module boundary changes require AIDEV updates.

## Current Commands

```sh
swift build
swift run HelloDaylily --check
swift run
```

If you start the server for smoke testing, stop it before finishing.

## Preferred Work Style

1. Divergence: discuss the problem space in conversation; do not write task docs or code.
2. Convergence: create or update the task file in `ai/tasks/` after the direction is chosen.
3. Build: implement the smallest runtime-safe change according to the task.
4. Review: audit code, API shape, AIDEV consistency, tests, and regressions.
5. Fix: address review findings and re-run validation.
6. Finish: update docs and task status, then commit and push.

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
let input = try request.json(CreateUser.self)
return JSON(User(...))
```

Next major feature is the streaming body model. It must not expose NIO types through public user APIs.

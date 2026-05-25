# Workflow

## Standard AI Loop

Before implementation:

1. Read `AIDEV.md`.
2. Read `ai/aidev/start-here.md`.
3. Read `ai/aidev/invariants.md`.
4. Read the relevant file under `ai/aidev/`.
5. Inspect source only as needed for exact edits.
6. Identify module boundary and public API impact.

During implementation:

1. Keep edits scoped.
2. Prefer runtime capability before macro syntax.
3. Do not introduce transport details into `DaylilyCore`.
4. Update AIDEV docs when public API or architecture changes.

After implementation:

1. Run `swift build`.
2. Run `swift run HelloDaylily --check`.
3. If server behavior changed, smoke test with `swift run` and `curl`.
4. Stop any local server started for verification.
5. Record task status in `ai/tasks/`.

## Source Reading Policy

AIDEV should be enough for project understanding.

Allowed source reading:

- exact edit locations
- compiler error investigation
- verification of a mismatch between AIDEV and implementation

Avoid source reading for:

- rediscovering architecture
- inventing module responsibilities
- guessing public API policy
- bypassing documented invariants

## Current Commands

Build:

```sh
swift build
```

Runtime checks:

```sh
swift run HelloDaylily --check
```

Run server:

```sh
swift run
```

Smoke test:

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/users/42
curl -X POST --data 'hi' http://127.0.0.1:8080/echo
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## Task Files

Tasks live in:

```text
ai/tasks/
```

Suggested file name:

```text
0008-streaming-body-model.md
```

Suggested structure:

```md
# 0002 Task Name

Status: proposed | in-progress | implemented | blocked

Goal:

- ...

Scope:

- ...

Non-goals:

- ...

Public API impact:

- ...

AIDEV updates required:

- ...

Validation:

- ...

Notes:

- ...
```

See `task-protocol.md` for the full protocol.

## ADR Files

Architecture decision records should live in:

```text
ai/adr/
```

Create `ai/adr/` when the first major architecture decision needs to be recorded.

Suggested file name:

```text
0001-runtime-before-macros.md
```

Use ADRs for decisions that are hard to reverse:

- macro architecture
- routing tree algorithm
- streaming body model
- dependency injection model
- JSON strategy
- OpenAPI generation strategy

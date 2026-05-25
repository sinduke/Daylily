# Workflow

## Work Modes

Daylily work moves through explicit modes. Do not skip modes unless the user asks for a small mechanical change.

### Divergence Mode

Purpose:

- Explore the problem space in conversation.
- Surface tradeoffs, risks, constraints, alternatives, and open questions.
- Keep the discussion lightweight and reversible.

Rules:

- Do not create or update task docs during divergence.
- Do not change source code during divergence.
- Do not mark registry or roadmap state as changed.
- Use the conversation to think, compare options, and find the shape of the work.

### Convergence Mode

Purpose:

- Turn the chosen direction into a written task.

Rules:

- Create or update the task file in `ai/tasks/`.
- Define goal, scope, non-goals, architecture impact, public API impact, AIDEV updates, validation, and open questions.
- Update roadmap or registry only when the project state actually changes.

### Build Mode

Purpose:

- Execute the converged task.

Rules:

- Implement according to the task document.
- Keep edits scoped.
- Prefer runtime capability before macro syntax.
- Add or update checks with the implementation.

### Review Mode

Purpose:

- Audit the work before declaring it done.

Rules:

- Review code, API shape, AIDEV consistency, tests, and likely regressions.
- Run required validation.
- Treat findings as blockers if they affect correctness, public API, or documented invariants.

### Fix Mode

Purpose:

- Address review findings.

Rules:

- Make focused fixes.
- Re-run relevant validation.
- Return to Review Mode after fixes.

### Finish Mode

Purpose:

- Close the task cleanly.

Rules:

- Update docs and task status after implementation and review are complete.
- Commit and push the finished work.
- Branch strategy is intentionally simple for now; use `main` until the project introduces a more detailed branching policy.

## Standard AI Loop

Before implementation:

1. Read `AIDEV.md`.
2. Read `ai/aidev/start-here.md`.
3. Read `ai/aidev/invariants.md`.
4. Read the relevant file under `ai/aidev/`.
5. Inspect source only as needed for exact edits.
6. Identify module boundary and public API impact.
7. If the user asks for divergence, stay in Divergence Mode and do not write docs yet.

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

## GitHub Actions CI

Workflow:

```text
.github/workflows/ci.yml
```

Triggers:

- push to `main`
- pull request to `main`
- manual `workflow_dispatch`

CI mirrors the required local validation:

```sh
swift build
swift run HelloDaylily --check
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

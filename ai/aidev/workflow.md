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

- Turn the chosen direction into a written epic/task/step shape.

Rules:

- Create or update the epic file in `ai/epics/` if the theme does not exist.
- Create or update the task file in `ai/tasks/`.
- Define goal, scope, non-goals, steps, architecture impact, public API impact, AIDEV updates, validation, and open questions.
- Keep sub-work as task-local steps, not `A/B/C` task files.
- Update roadmap or registry only when the project state actually changes.

### Build Mode

Purpose:

- Execute the converged task or one of its steps.

Rules:

- Implement according to the task document.
- Keep edits scoped.
- Prefer runtime capability before macro syntax.
- Add or update checks with the implementation.
- If executing a step, update only that step's checklist/status; do not treat the step as a commit unit.

### Review Mode

Purpose:

- Audit a step or task before declaring it done.

Rules:

- Review code, API shape, AIDEV consistency, tests, and likely regressions.
- Run required validation.
- Treat findings as blockers if they affect correctness, public API, or documented invariants.
- Step review can close a step, but cannot trigger commit or push.
- Task review can close a full task after all required steps are complete.

### Fix Mode

Purpose:

- Address review findings.

Rules:

- Make focused fixes.
- Re-run relevant validation.
- Return to Review Mode after fixes.

### Finish Mode

Purpose:

- Close a task cleanly.

Rules:

- Update docs and task status after implementation and review are complete.
- Commit and push only at the task level.
- Do not commit or push after completing only a step or sub-step.
- Branch strategy is intentionally simple for now; use `main` until the project introduces a more detailed branching policy.

## Work Unit Hierarchy

Daylily work uses three levels:

```text
Epic -> Task -> Step
```

Epic:

- Theme or product area.
- Stored in `ai/epics/`.
- Example: `0008-body-system.md`.
- Not a direct implementation unit.

Task:

- Smallest commit/push unit.
- Stored in `ai/tasks/`.
- File name format: `NNNN-XXX-short-kebab-name.md`.
- Example: `0008-002-nio-true-streaming-bridge.md`.

Step:

- Temporary execution unit inside a task.
- Stored as a checklist inside the task file.
- Example: `0008-002.1 Feed NIO chunks`.
- May be built, reviewed, and fixed independently.
- Must not be committed or pushed independently.

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
4. Update AIDEV docs when public API, architecture, or workflow changes.

After implementation:

1. Run `swift build`.
2. Run `swift run HelloDaylily --check`.
3. If server behavior changed, smoke test with `swift run` and `curl`.
4. Stop any local server started for verification.
5. Record task and step status in `ai/tasks/`.
6. Commit and push only if a full task is complete and reviewed.

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

## Epic and Task Files

Epics live in:

```text
ai/epics/
```

Suggested epic file name:

```text
0009-middleware-system.md
```

Tasks live in:

```text
ai/tasks/
```

Suggested file name:

```text
0009-001-middleware-runtime.md
```

Suggested structure:

```md
# 0009-001 Task Name

Status: proposed | in-progress | implemented | blocked
Epic: 0009-middleware-system

Goal:

- ...

Scope:

- ...

Non-goals:

- ...

Steps:

- [ ] 0009-001.1 ...
- [ ] 0009-001.2 ...

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

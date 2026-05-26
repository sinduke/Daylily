# Task Protocol

Daylily work is tracked with three levels:

```text
Epic -> Task -> Step
```

The goal is to keep AI work understandable without turning every small execution step into a commit.

## Levels

### Epic

An epic is a theme or product area.

Examples:

- `0008 Body System`
- `0009 Middleware System`

Epic files live in:

```text
ai/epics/
```

File name:

```text
NNNN-short-kebab-name.md
```

Example:

```text
0008-body-system.md
```

Epics are planning containers. Do not implement directly against an epic without choosing a task.

### Task

A task is the smallest commit/push unit.

Task files live in:

```text
ai/tasks/
```

File name:

```text
NNNN-XXX-short-kebab-name.md
```

Where:

- `NNNN` is the epic id.
- `XXX` is the task id inside that epic.

Example:

```text
0008-002-nio-true-streaming-bridge.md
```

### Step

A step is a temporary execution unit inside a task.

Steps do not get their own files. Track them as a checklist inside the task:

```md
## Steps

- [ ] 0008-002.1 Create transport SPI
- [ ] 0008-002.2 Feed NIO chunks
- [ ] 0008-002.3 Finish/fail stream
- [ ] 0008-002.4 Add checks
- [ ] 0008-002.5 Review
```

Step completion may enter review/fix, but must not commit or push by itself.

## Status Values

Use one of:

```text
proposed
in-progress
implemented
blocked
superseded
```

## Required Task Sections

```md
# NNNN-XXX Task Name

Status: proposed
Epic: NNNN-short-kebab-name

Goal:

- ...

Scope:

- ...

Non-goals:

- ...

Steps:

- [ ] NNNN-XXX.1 ...

Architecture impact:

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

## Before Starting

An AI should:

1. Read `AIDEV.md`.
2. Read `ai/aidev/start-here.md`.
3. Read this task protocol.
4. Identify the epic and task.
5. If the user is still in divergence, discuss options in conversation and do not create or update task files yet.
6. Create or update task files only after the work enters convergence.
7. Keep steps inside the task file instead of creating `A/B/C` task files.
8. State the task and active step in the working notes or conversation.

## During Work

Keep the task file honest:

- Mark the task `in-progress` when implementation starts.
- Mark individual steps as complete as they pass review.
- Record scope changes.
- Record deliberate non-goals.
- Record any AIDEV files updated.

## Review and Fix

Review can happen at two levels:

- Step review: validates a step and may lead to fixes, but does not commit or push.
- Task review: validates the whole task and can proceed to task finish.

If review finds issues, enter Fix Mode for the relevant step or task, then return to review.

## Completion

Before marking a task `implemented`:

1. Complete all required steps.
2. Run validation commands.
3. Update AIDEV docs if needed.
4. Update `registry.yml` if public API, modules, commands, roadmap, or feature state changed.
5. Summarize what changed.

Only task-level completion may enter Finish Mode for commit and push.

## Small Changes

Tiny typo fixes do not need a new task file.

Any change that affects architecture, public API, runtime behavior, commands, or AI workflow needs a task.

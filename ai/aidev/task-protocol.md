# Task Protocol

Every meaningful change should have a task file in `ai/tasks/`.

## File Name

```text
NNNN-short-kebab-name.md
```

Example:

```text
0003-aidev-self-contained-spec.md
```

## Status Values

Use one of:

```text
proposed
in-progress
implemented
blocked
superseded
```

## Required Sections

```md
# NNNN Task Name

Status: proposed

Goal:

- ...

Scope:

- ...

Non-goals:

- ...

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
4. If the user is still in divergence, discuss options in conversation and do not create or update task files yet.
5. Create or update the task file only after the work enters convergence.
6. State the task's scope in the working notes or conversation.

## During Work

Keep the task file honest:

- Mark `in-progress` when implementation starts.
- Record scope changes.
- Record deliberate non-goals.
- Record any AIDEV files updated.

## Completion

Before marking `implemented`:

1. Run validation commands.
2. Update AIDEV docs if needed.
3. Update `registry.yml` if public API, modules, commands, roadmap, or feature state changed.
4. Summarize what changed.

## Small Changes

Tiny typo fixes do not need a new task file.

Any change that affects architecture, public API, runtime behavior, commands, or AI workflow needs a task.

# 0003 AIDEV Self-Contained Spec

Status: implemented

Goal:

- Upgrade AIDEV from a project note into a self-contained AI handoff specification.
- Make it possible for an AI to understand Daylily's purpose, architecture, API, invariants, extension paths, and workflow before reading source code.

Scope:

- Add `start-here.md`.
- Add core concept documentation.
- Add runtime contracts.
- Add invariants.
- Add extension playbooks.
- Add task protocol.
- Add standard agent prompt.
- Expand machine-readable registry.
- Update AIDEV index, README, project map, workflow, and roadmap.

Non-goals:

- Add macro implementation.
- Add a command-line `aidev` tool.
- Change runtime behavior.
- Change public Swift API.

Architecture impact:

- No runtime architecture changes.
- AIDEV becomes the authoritative AI project map.

Public API impact:

- None.

AIDEV updates required:

- Completed in this task.

Validation:

- `swift build`
- `swift run HelloDaylily --check`

Notes:

- Source code may still be read for exact edits, but AI should not need source spelunking to understand the project.

